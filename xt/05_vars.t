#!perl -w

use strict;
use Test::More;

use Test::Vars;

all_vars_ok(
    ignore_vars => [qw($parser $symol)],
);

done_testing;
