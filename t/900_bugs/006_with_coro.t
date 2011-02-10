#!perl
# vim:ft=perl:
# reported by cho45
# modified from https://github.com/gfx/p5-Text-Xslate/issues#issue/27
use strict;
use warnings;
use Test::More skip_all => 'Not yet resolved';
use Test::Requires qw(Coro);

use Text::Xslate;

my $XSLATE = Text::Xslate->new(
    syntax => 'TTerse',
    cache     => 0,
);

my $template = <<'EOF';
[% JS = [
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
    "aaaaaaaaaa",
] %]
foobar
EOF

my $coro = async { $XSLATE->render_string($template) };
like $coro->join(), qr/foobar/;

done_testing;
