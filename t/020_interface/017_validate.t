#!perl
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my %vpath = (
    ok0 => <<'T',
Hello, world!
T

    ok1=> <<'T',
Hello, <: $xslate :> world!
T

    ng0=> <<'T',
Hello, <: $xslate world!
T

    ng1=> <<'T',
Hello, <: $xslate ??? :> world!
T
);

my $tx = Text::Xslate->new(path => [\%vpath]);

foreach my $name (qw(ok0 ok1)) {
    eval { $tx->validate($name) };
    ok !$@, $name;
    note $@ if $@;
}

foreach my $name (qw(ng0 ng1)) {
    eval { $tx->validate($name) };
    ok $@, $name;
    note $@ if $@;
}

done_testing;
