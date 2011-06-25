#!perl
use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new();

is $tx->render_string('<: __ROOT__["foo"] :>', { foo => 42 }), '42';
is $tx->render_string('<: __ROOT__.foo :>',    { foo => 42 }), '42';

is $tx->render_string(
    '<: __ROOT__.merge({ foo => "bar"}).foo ~ __ROOT__.foo :>', { foo => 42 }),
    'bar42';

done_testing;

