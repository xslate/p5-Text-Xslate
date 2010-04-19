#!perl -w

use strict;
use Test::More;

use Test::Requires qw(Test::Vars);

all_vars_ok(
    ignore_vars => [qw($parser $symbol)],
);

done_testing;
