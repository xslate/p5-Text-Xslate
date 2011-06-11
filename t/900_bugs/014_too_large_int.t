#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new();

is $tx->render_string(': "10" x 100'),
                         "10" x 100;

is $tx->render_string(': "1000000000000000000000000000" '),
                         "1000000000000000000000000000";

done_testing;

