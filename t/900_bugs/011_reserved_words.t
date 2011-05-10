#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(
    syntax => 'TTerse',
);

is eval {
    $tx->render_string(<<'T');
[% block = "Hello" -%]
[% block %]
T
}, undef;
isnt $@, '';
like $@, qr/not a lexical variable/;

done_testing;

