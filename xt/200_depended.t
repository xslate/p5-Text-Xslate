#!perl -w
use strict;
use Test::More;
use File::Path qw(rmtree);
use File::Which qw(which);

use constant LDIR => '.test_deps';
BEGIN{ rmtree(LDIR) }
END  { rmtree(LDIR) }

my @opts = qw(-q --reinstall);
if(!scalar grep { $_ eq '--install' } @ARGV) {
    push @opts, '-l', LDIR;
}
my $cpanm = which('cpanm') or plan skip_all => 'no cpanm';

my @modules = qw(
    Text::Xslate::Bridge::TT2Like
    Catalyst::View::Xslate
);

foreach my $mod(@modules) {
    note $mod;
    is system($^X, $cpanm, @opts, $mod), 0, $mod;
}

done_testing;

