#!perl
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

# for strings
my $template = <<'T';
: my $foo = 'Hello, world!';
: for [1] -> $i {
    : $foo
: }
T

is $tx->render_string($template), 'Hello, world!';
done_testing;

