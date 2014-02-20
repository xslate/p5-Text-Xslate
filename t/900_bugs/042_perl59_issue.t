#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/105
use strict;
use warnings;
use utf8;
use Test::More 0.96;

# This code cause segmentation fault on Perl 5.19.[79].

use Text::Xslate;

my $xslate = Text::Xslate->new();
$xslate->render_string(<<'...');
: '/' ~ uri('a')
: for 3 -> $n { }
...

pass;

done_testing;
