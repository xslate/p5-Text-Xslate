#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/88
use strict;
use warnings;
use Test::More;

use utf8;
use Text::Xslate 'mark_raw';
my $xslate = Text::Xslate->new();

is $xslate->render_string('<: $string :>', {string => "Ä"})      => 'Ä';
is $xslate->render_string('<: $string :>', {string => "\x{c4}"}) => 'Ä';

is $xslate->render_string('あ<: $string :>', {string => "Ä"})      => 'あÄ';
is $xslate->render_string('あ<: $string :>', {string => "\x{c4}"}) => 'あÄ';

is $xslate->render_string('<: $string :>', {string => mark_raw("Ä")})      => 'Ä';
is $xslate->render_string('<: $string :>', {string => mark_raw("\x{c4}")}) => 'Ä';

is $xslate->render_string('あ<: $string :>', {string => mark_raw("Ä")})      => 'あÄ';
is $xslate->render_string('あ<: $string :>', {string => mark_raw("\x{c4}")}) => 'あÄ';

done_testing();
