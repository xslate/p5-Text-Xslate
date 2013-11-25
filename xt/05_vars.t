#!perl -w

use strict;
use Test::More;

use Test::Requires qw(Test::Vars);

all_vars_ok(
    ignore_vars => [qw($parser $symbol $note_guard)],
);

done_testing;
