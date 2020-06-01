#!perl
use strict;
use warnings;

use Fatal qw(utime);

use FindBin qw($Bin);
use File::Path qw(rmtree);
use Config ();
use Test::More;

use Text::Xslate;

my $dir = "$Bin/issue79";

rmtree "$dir/cache";

my $run_cmd = qq{$^X "$dir/xslate.pl"};
note $run_cmd;

my @tmpls = qw/ contentA.tt contentB.tt /;

note 'run with cache';
my $expected = `$run_cmd`;
is $?, 0, 'process succeed';
utime time()+2, time()+2, map { "$dir/tmpl/$_" } @tmpls;

my $got = `$run_cmd`;
is $?, 0, 'process succeed';
is $got, $expected;

done_testing;
