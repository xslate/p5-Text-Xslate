#!perl
use strict;
use Test::More;
eval q{use Test::Synopsis};
plan skip_all => 'Test::Synopsis required for testing' if $@;
local $SIG{__WARN__} = sub {
    warn @_ if $_[0] !~ /redefined/;
};
all_synopsis_ok();
