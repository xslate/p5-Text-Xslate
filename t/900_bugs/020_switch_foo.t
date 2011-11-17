#!perl
# http://twitter.com/#!/ryochin/status/137041211054768128
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(
    syntax => 'TTerse',
    cache  => 0,
);

eval {
    $tx->render_string(<<'T');
    %% if
T
};
ok $@;

eval {
    $tx->render_string(<<'T');
    %% switch.foo
T
};
ok $@;

done_testing;

