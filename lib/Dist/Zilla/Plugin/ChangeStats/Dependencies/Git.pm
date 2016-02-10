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
use CPAN::Changes;
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
has release_branch => (
    is => 'ro',
    isa => Str,
    default => 'releases',
);
has auto_previous_tag => (
    is => 'ro',
    isa => Bool,
    default => 0,
);
has group => (
    is => 'ro',
    isa => Str,
    default => '',
);
has stats => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    traits => ['Hash'],
    builder => '_build_stats',
    init_arg => undef,
);

sub _build_stats {
    my $self = shift;
    use Data::Printer;
    p $self->zilla;

    my $prev = $self->auto_previous_tag ? $self->_get_previous_tag : $self->release_branch;
    return {} if !defined $prev;
warn '----';
    p $prev;
    warn '----';
    $self->repo->run(qw/show META:json/);
    warn $prev;
    return {};
}

sub _get_previous_tag {
    my $self = shift;

    my @plugins = grep { $_->isa('Dist::Zilla::Plugin::Git::Tag') } @{ $self->zilla->plugins_with( '-Git::Repo' ) };

    die "We dont know what to do with multiple Git::Tag plugins loaded!" if scalar @plugins > 1;
    die "Please load the Git::Tag plugin to use auto_release_tag or disable it!" if ! scalar @plugins;

    (my $match = $plugins[0]->tag_format) =~ s/\%\w/\.\+/g; # hack.
    $match = (grep { $_ =~ /$match/ } $self->repo->run('tag'))[-1];

    if(!defined $match ) {
        $self->log('Unable to find the previous tag, trying to find the first commit!');
        $match = $self->repo->run('rev-list',  '--max-parents=0', 'HEAD');
        if(!defined $match ) {
            $self->log('Unable to find the first commit, giving up!');
            return;
        }
    }
    return $match;
}

sub munge_files {
    my $self = shift;
        use Data::Printer;
    my($file) = grep { $_->name eq $self->change_file } @{ $self->zilla->files };

    my $changes = CPAN::Changes->load_string($file->content, next_token => $self->_next_token);

    my($previous_release) = grep { $_->version ne '{{$NEXT}}' } reverse $changes->releases;

    if(!defined $previous_release) {
        $self->log(['Has no earlier versions in changelog - no dependency changes']);
        return;
    }

    p $previous_release;
    warn '--' x 20;
}

sub _next_token { qr/\{\{\$NEXT\}\}/ }

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 SYNOPSIS

    use Dist::Zilla::Plugin::ChangeStats::Dependencies::Git;

=head1 DESCRIPTION

Dist::Zilla::Plugin::ChangeStats::Dependencies::Git is ...

=head1 SEE ALSO

=cut
