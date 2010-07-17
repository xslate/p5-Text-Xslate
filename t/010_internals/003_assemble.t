#!perl -w
# The purpose of this test is to ensure that _assemble() ends successfully.

use strict;
use Test::More tests => 4;

use Text::Xslate;

my %vpath = (
    hello => 'Hello, world!',
);


for my $n(1 .. 2) {
    my $tx = Text::Xslate->new(cache => 0, path => \%vpath);
    eval {
        $tx->load_file('hello');
    };
    is $@, '', "assemble inside of eval {}  ($n)";

    $tx = Text::Xslate->new(cache => 0, path => \%vpath);
    $tx->load_file('hello');
    pass "assemble outside of eval {} ($n)";
}

