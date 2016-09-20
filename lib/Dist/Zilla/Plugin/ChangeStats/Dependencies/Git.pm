use 5.10.1;
use strict;
use warnings;

package Dist::Zilla::Plugin::ChangeStats::Dependencies::Git;

# ABSTRACT: Add dependency changes to the changelog
# AUTHORITY
our $VERSION = '0.0201';

use Moose;
use namespace::autoclean;
use Types::Standard qw/ArrayRef Bool HashRef Str/;
use Git::Repository;
use Module::CPANfile;
use Path::Tiny;
use Try::Tiny;
use CPAN::Changes;
use CPAN::Changes::Group;
use JSON::MaybeXS qw/decode_json/;

with qw/
    Dist::Zilla::Role::Plugin
    Dist::Zilla::Role::FileMunger
/;

sub mvp_multivalue_args { qw/stats_skip_file stats_skip_match/ }

has repo => (
    is => 'ro',
    default => sub { Git::Repository->new(work_tree => '.')},
);
has change_file => (
    is => 'ro',
    isa => Str,
    default => 'Changes',
);
has group => (
    is => 'ro',
    isa => Str,
    default => '',
);
has format_tag => (
    is => 'ro',
    isa => Str,
    default => '%s',
);
has add_to_first_release => (
    is => 'ro',
    isa => Bool,
    default => 0,
);

has do_stats => (
    is => 'ro',
    isa => Bool,
    default => 0,
);
has stats_skip_file => (
    is => 'ro',
    isa => ArrayRef[Str],
    traits => ['Array'],
    default => sub { [] },
    handles => {
        all_stats_skip_files => 'elements',
        has_stats_skip_files => 'count',
    }
);
has stats_skip_match => (
    is => 'ro',
    isa => ArrayRef[Str],
    traits => ['Array'],
    default => sub { [] },
    handles => {
        all_stats_skip_matches => 'elements',
        has_stats_skip_matches => 'count',
    }
);
has stats_text => (
    is => 'ro',
    isa => Str,
    default => 'Code churn',
);



sub munge_files {
    my $self = shift;

    my($file) = grep { $_->name eq $self->change_file } @{ $self->zilla->files };

    if(!defined $file) {
        $self->log(['Could not find changelog (%s) - nothing to do', $self->change_file]);
        return;
    }

    my $changes = CPAN::Changes->load_string($file->content, next_token => $self->_next_token);
    my($this_release) = ($changes->releases)[-1];
    if($this_release->version ne '{{$NEXT}}') {
        $self->log(['Could not find {{$NEXT}} token - skips']);
        return;
    }

    if(!path('META.json')->exists) {
        $self->log(['Could not find META.json in distribution root - skips']);
        return;
    }
    my $current_meta = decode_json(path('META.json')->slurp)->{'prereqs'};

    my($previous_release) = grep { $_->version ne '{{$NEXT}}' } reverse $changes->releases;

    my $is_first_release = defined $previous_release ? 0 : 1;

    my $tag_meta;
    my $git_tag;
    if($self->add_to_first_release && $is_first_release) {
        $self->log(['First release - adds all dependencies']);
        $tag_meta = {}; # fake meta
    }
    elsif($is_first_release) {
        $self->log(['Has no earlier versions in changelog - no dependency changes']);
        return;
    }
    else {
        $self->log_debug(['Will compare dependencies with %s'], $previous_release->version);
        $git_tag = sprintf $self->format_tag, $previous_release->version;

        $tag_meta = $self->get_meta($git_tag);
        if(!defined $tag_meta || !defined $current_meta) {
            return;
        }
    }

    my @all_requirement_changes = ();

    PHASE:
    for my $phase (qw/runtime test build configure develop/) {
        RELATION:
        for my $relation (qw/requires recommends suggests/) {
            my $requirement_changes = {
                added => [],
                changed => [],
                removed => [],
            };

            my $prev = $tag_meta->{ $phase }{ $relation } || {};
            my $now = $current_meta->{ $phase }{ $relation } || {};

            next RELATION if !scalar keys %{ $prev } && !scalar keys %{ $now };

            # What is in the current release that wasn't in (or has changed since) the last release.
            MODULE:
            for my $module (sort keys %{ $now }) {
                my $current_version = delete $now->{ $module } || '(any)';
                my $previous_version = exists $prev->{ $module } ? delete $prev->{ $module } : undef;

                if(!defined $previous_version) {
                    push @{ $requirement_changes->{'added'} } => "$module $current_version";
                    next MODULE;
                }

                $previous_version = $previous_version || '(any)';
                if($current_version ne $previous_version) {
                    push @{ $requirement_changes->{'changed'} } => "$module $previous_version --> $current_version";
                }
            }
            # What was in the last release that currenly isn't there
            for my $module (sort keys %{ $prev }) {
                push @{ $requirement_changes->{'removed'} } => $module;
            }

            # Add requirement changes to overall list
            for my $type (qw/added changed removed/) {
                my $char = $type eq 'added' ? '+' : $type eq 'changed' ? '~' : $type eq 'removed' ? '-' : '!';

                for my $module (@{ $requirement_changes->{ $type }}) {
                    push @all_requirement_changes => ($self->phase_relation($phase, $relation) . " $char $module");
                }
            }
        }
    }

    my $group = $this_release->get_group($self->group);
    $self->add_stats($group, $git_tag) if !$is_first_release && $self->do_stats;
    $group->add_changes(@all_requirement_changes);
    $file->content($changes->serialize);
}

sub get_meta {
    my $self = shift;
    my $tag = shift;

    my(@tags) = $self->repo->run('tag');
    my($found) = grep { $_ eq $tag } @tags;

    if(!$found) {
        $self->log(['Could not find tag %s - skipping', $tag]);
        return;
    }

    my $show_output;
    try {
        ($show_output) = join '' => $self->repo->run('show', join ':' => ($tag, 'META.json'));
    }
    catch {
        if($_ =~ m{^fatal:}) {
            $self->log(['Could not find META.json in %s - skipping', $tag]);
        }
        die $_;
    };
    return if !defined $show_output;
    return decode_json($show_output)->{'prereqs'};
}

sub phase_relation {
    my $self = shift;
    my $phase = shift;
    my $relation = shift;

    $phase = $phase eq 'runtime'   ? 'run'
           : $phase eq 'test'      ? 'test'
           : $phase eq 'configure' ? 'conf'
           : $phase eq 'develop'   ? 'dev'
           :                         $phase
           ;
    $relation = substr $relation, 0, 3;

    return "($phase $relation)";
}

sub _next_token { qr/\{\{\$NEXT\}\}/ }

sub add_stats {
    my $self = shift;
    my $group = shift;
    my $git_tag = shift;

    my @numstats = $self->repo->run(qw/diff --numstat/, $git_tag);
    my $counter = {
        files => 0,
        insertions => 0,
        deletions => 0,
    };

    FILE:
    for my $file (@numstats) {
        my($insertions, $deletions, $path) = split /\s+/, $file, 3;
        next FILE if grep { $path eq $_ } $self->all_stats_skip_files;
        next FILE if grep { $path =~ m{$_}i } $self->all_stats_skip_matches;

        # binary files get '-'
        ++$counter->{'files'};
        $counter->{'insertions'} += $insertions =~ m{^\d+$} ? $insertions : 0;
        $counter->{'deletions'}  += $deletions  =~ m{^\d+$} ? $deletions  : 0;
    }

    my $output = sprintf '%d file%s changed, %d insertion%s(+), %d deletion%s(-)',
                         $counter->{'files'},
                         $counter->{'files'} == 1 ? '': 's',
                         $counter->{'insertions'},
                         $counter->{'insertions'} == 1 ? '': 's',
                         $counter->{'deletions'},
                         $counter->{'deletions'} == 1 ? '': 's';

    my $intro = length $self->stats_text ? $self->stats_text . ': ' : '';

    $group->add_changes($intro . $output);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 SYNOPSIS

    ; in dist.ini
    [ChangeStats::Dependencies::Git]
    group = Dependency Changes

=head1 DESCRIPTION

This plugin adds detailed information about changes in requirements to the changelog, possibly in a group. The
synopsis might add this:

     [Dependency Changes]
     - (run req) + Moose (any)
     - (run req) - No::Longer::Used
     - (test sug) + Something::Useful 0.82
     - (dev req) ~ List::Util 1.40 --> 1.42

For this to work the following must be true:

=for :list
* The changelog must conform to L<CPAN::Changes::Spec>.
* There must be a C<META.json> in both the working directory and in the tags.
* Git tag names must be identical to (or a superset of) the version numbers in the changelog.
* This plugin should come before [NextRelease] or similar in dist.ini.

=head1 ATTRIBUTES


=head2 change_file

Default: C<Changes>

The name of the changelog file.


=head2 group

Default: No group

The group (if any) under which to add the dependency changes. If the group already exists these changes will be appended to that group.


=head2 format_tag

Default: C<%s>

Use this if the Git tags are formatted differently to the versions in the changelog. C<%s> gets replaced with the version.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Plugin::ChangeStats::Git>

=cut
