#!perl -w
use strict;
use warnings;

use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'TTerse', macro => ['t/template/macro.tt']);

is $tx->render_string(<<'T'), <<'X';
{[% foo() %]}
T
{foo}
X

done_testing;

