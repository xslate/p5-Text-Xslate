#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/111
use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new();

is($tx->render_string('1'), '1');
is($tx->render_string('0'), '0');

done_testing;
