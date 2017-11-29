#!perl -w

use strict;
use Test::More;

use Test::Requires qw(Test::Vars);
use File::Find ();

my @file;
my $wanted = sub { push @file, $_ if -f && /\.pm$/ };
File::Find::find({wanted => $wanted, no_chdir => 1}, "lib");

vars_ok $_, ignore_vars => [qw($parser $symbol $)] for @file;

done_testing;
