use strict;
use warnings;
use Test::More;
use syntax 'qi';
use JSON::MaybeXS qw/encode_json/;
use if $ENV{'AUTHOR_TESTING'}, 'Test::Warnings';

use Dist::Zilla::Plugin::ChangeStats::Dependencies::Git;

use Test::DZil;

subtest first_release => sub {
    my $tzil = make_tzil({ auto_previous_tag => 1 });

    like $tzil->slurp_file('build/Changes'),
        qr{ 
            0\.0002
            \s+
            2[-\d\s:+]+    # date+time
            [\w/]+         # timezone
            [\n\r\s]*$     # empty
        }x, 'First release, no dependency changes';

};

subtest normal => sub {

    my $tzil = make_tzil({ auto_previous_tag => 1 }, qi{
        0.0001    Unreleased
         - Not much of a change
    });


    like $tzil->slurp_file('build/Changes'),
        qr/
            \[STATISTICS\]\s*\n
            \s*-\s*code\schurn:\s+\d+\sfiles?\schanged,
            \s\d+\sinsertions?\(\+\),\s\d+\sdeletions?\(-\)
        /x,
        'using skip_file without hit';
};

done_testing;

sub make_tzil {
    my $changestats_args = shift;
    my $changes = shift || '';

    my $ini = simple_ini(
        { version => '0.0002' },
        [ 'ChangeStats::Dependencies::Git', $changestats_args ],
        qw/
            GatherDir
            NextRelease
            FakeRelease
            Git::Tag
        /
    );
    my $changelog = qqi{
        Revision history for {{\$dist->name}}

        {{\$NEXT}}

        $changes
    };

    my $tzil = Builder->from_config(
        {   dist_root => '/t' },
        {
            add_files => {
                'source/dist.ini' => $ini,
                'source/Changes' => $changelog,
                'source/META.json' => meta_json(),
            },
        },
    );
    $tzil->build;
    return $tzil;
}

sub meta_json {
   return encode_json({
        'prereqs' => {
          'configure' => {
             'requires' => {
                'ExtUtils::MakeMaker' => '0'
             }
          },
          'develop' => {
             'requires' => {
                'Dist::Zilla::Plugin::BumpVersionAfterRelease::Transitional' => '0',
                'Dist::Zilla::Plugin::CheckChangesHasContent' => '0',
                'Dist::Zilla::Plugin::ExecDir' => '0',
                'Dist::Zilla::Plugin::Git::Check' => '0',
                'Dist::Zilla::Plugin::Git::Contributors' => '0',
                'Dist::Zilla::Plugin::Git::GatherDir' => '0',
                'Dist::Zilla::Plugin::Git::Push' => '0',
                'Test::More' => '0.96',
                'Test::NoTabs' => '0',
                'Test::Pod' => '1.40',
                'Test::Warnings' => '0'
             }
          },
          'runtime' => {
             'requires' => {
                'perl' => '5.010002',
                'Moose' => 2.1400,
             }
          },
          'test' => {
             'recommends' => {
                'CPAN::Meta' => '2.120900'
             },
             'requires' => {
                'ExtUtils::MakeMaker' => '0',
                'File::Spec' => '0',
                'IO::Handle' => '0',
                'IPC::Open3' => '0',
                'Test::More' => '0.96'
             }
          }
       },
    });
}
