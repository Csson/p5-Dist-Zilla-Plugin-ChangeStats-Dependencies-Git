use 5.10.1;
use strict;
use warnings;

package Dist::Zilla::Plugin::ChangeStats::Dependencies::Git;

# ABSTRACT: Add dependency changes to the changelog
our $VERSION = '0.0100';

use Moose;
use namespace::autoclean;
use Types::Standard qw/ArrayRef Bool HashRef Str/;
use Git::Repository;
use Module::CPANfile;
use CPAN::Changes;
use CPAN::Changes::Group;
use JSON::MaybeXS qw/decode_json/;

with qw/
    Dist::Zilla::Role::Plugin
    Dist::Zilla::Role::FileMunger
/;

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
        $self->log(['Cound not find {{$NEXT}} token - skips']);
        return;
    }

    my($previous_release) = grep { $_->version ne '{{$NEXT}}' } reverse $changes->releases;

    if(!defined $previous_release) {
        $self->log(['Has no earlier versions in changelog - no dependency changes']);
        return;
    }
    else {
        $self->log_debug(['Will compare dependencies with %s'], $previous_release->version);
    }

    # Fetch META.json from the latest tag
    my($show_output) = join '' => $self->repo->run('show', join ':' => (sprintf ($self->format_tag, $previous_release->version), 'META.json'));
    if($show_output =~ m{^fatal:}) {
        $self->log(['Could not find META.json in the %s release - skipping', $previous_release->version]);
        return;
    }
    my $metajson = decode_json($show_output)->{'prereqs'};
    my $cpanfile = Module::CPANfile->load->prereqs->as_string_hash;

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

            my $prev = $metajson->{ $phase }{ $relation } || {};
            my $now = $cpanfile->{ $phase }{ $relation } || {};

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
    $group->add_changes(@all_requirement_changes);
    $file->content($changes->serialize);
}

sub _next_token { qr/\{\{\$NEXT\}\}/ }

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
* There must be a L<C<panfile>> (this is the source of current dependencies) in the distribution root.
* Git tag names must be identical to (or a superset of) the version numbers in the changelog.
* There must be a C<META.json> commited in the git tags.
* The plugin should come before [NextRelease] or similar in dist.ini.

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
