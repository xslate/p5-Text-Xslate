#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new();

is($tx->render_string('1'), '1');
is($tx->render_string('0'), '0');

done_testing;

