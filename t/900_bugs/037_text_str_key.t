use strict;
use warnings;
use utf8;
use Test::More;

use Text::Xslate;


my $tx = Text::Xslate->new(
    cache => 0,
);

is $tx->render_string(<<'T'), 10;
: my $h = { "こんにちは" => 10};
:= $h["こんにちは"]
T

is $tx->render_string(<<'T', { key => "こんにちは"}), 10;
: my $h = { "こんにちは" => 10};
:= $h[$key]
T

done_testing;
