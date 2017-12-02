#!perl -w
use strict;
use Test::More;
use File::Path qw(rmtree);
use Test::Requires 'File::Which';
plan skip_all => 'disable on windows' if $^O eq 'MSWin32';

use constant LDIR => '.test_deps';
BEGIN{ rmtree(LDIR) }
END  { rmtree(LDIR) }

my $cpanm = File::Which::which('cpanm') or plan skip_all => 'no cpanm';

my @modules = qw(
    Text::Xslate::Bridge::TT2Like
    Catalyst::View::Xslate
);

foreach my $mod(@modules) {
    note $mod;
    is system($^X, $cpanm, -l => LDIR, qw(-nq --installdeps), $mod), 0, $mod;
    is system($^X, $cpanm, -l => LDIR, qw(-q --test-only), $mod), 0, $mod;
}

done_testing;

