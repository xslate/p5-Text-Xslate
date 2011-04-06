#!perl -w
use strict;
use if exists $INC{'Text/Xslate.pm'},
    'Test::More', skip_all => 'Text::Xslate has been loaded';
use Test::More;
BEGIN{ $ENV{XSLATE} ||= ''; $ENV{XSLATE} .= ':save_src' }

use Text::Xslate;

my $tx = Text::Xslate->new(
    path  => { foo => 'Hello, <: "" :>world!' },
    cache => 0,
);

is $tx->render('foo'), 'Hello, world!';
is $tx->{source}{foo}, 'Hello, <: "" :>world!';

is $tx->render_string('<: 1 + 41 :>'), 42;
is $tx->{source}{'<string>'}, '<: 1 + 41 :>';

done_testing;
