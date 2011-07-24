#!perl
# vim:ft=perl:
# reported by cho45
# modified from https://github.com/gfx/p5-Text-Xslate/issues#issue/27
use strict;
use warnings;
use Test::More;
use Text::Xslate;
use Text::Xslate::Parser;

my $template = sprintf <<'EOF', qq{    "a",\n} x 5000;
[%% JS = [
%s
] %%]
foobar
EOF

my $XSLATE = Text::Xslate->new(
    syntax => 'TTerse',
    cache     => 0,
);

like $XSLATE->render_string($template), qr/foobar/;

done_testing;
