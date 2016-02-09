use strict;
use warnings;
use Test::More;
use if $ENV{'AUTHOR_TESTING'}, 'Test::Warnings';

use Dist::Zilla::Plugin::ChangeStats::Dependencies::Git;
ok 1, 'Loaded';

done_testing;
