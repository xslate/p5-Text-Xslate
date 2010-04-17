#!perl -w
use strict;
use Test::More;

use Text::Xslate;

use FindBin qw($Bin);

my $tx = Text::Xslate->new(
    string => <<'TX',
Hello, <?= $value | uc ?> world!
TX
    function => {
        uc => sub{ uc $_[0] },
    },
);

is $tx->render({ value => 'Xslate' }), "Hello, XSLATE world!\n";

$tx = Text::Xslate->new(
    string => <<'TX',
Hello, <?= uc($value) ?> world!
TX
    function => {
        uc => sub{ uc $_[0] },
    },
);

is $tx->render({ value => 'Xslate' }), "Hello, XSLATE world!\n";

done_testing;
