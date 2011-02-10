#!perl
# vim:ft=perl:
# reported by cho45
# modified from https://github.com/gfx/p5-Text-Xslate/issues#issue/27
use strict;
use warnings;
use Test::More
#    skip_all => 'Not yet resolved'
;
use Text::Xslate;

my $XSLATE = Text::Xslate->new(
    syntax => 'TTerse',
    cache     => 0,
);

my $template = sprintf <<'EOF', qq{    "a",\n} x 10000;
[%% JS = [
%s
] %%]
foobar
EOF

like $XSLATE->render_string($template), qr/foobar/;

done_testing;
