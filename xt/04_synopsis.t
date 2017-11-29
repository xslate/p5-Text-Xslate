#!perl
use strict;
use Test::More;
use Test::Requires 'Test::Synopsis';
use File::Find ();

my @file;
my $wanted = sub { push @file, $_ if -f && /\.(?:pm|pod)$/ };
File::Find::find({wanted => $wanted, no_chdir => 1}, "lib");

synopsis_ok(@file);

done_testing;
