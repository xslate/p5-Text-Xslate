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
is $tx->render({ value => 'Perl' }),   "Hello, PERL world!\n";

$tx = Text::Xslate->new(
    string => <<'TX',
Hello, <?= uc($value) ?> world!
TX
    function => {
        uc => sub{ uc $_[0] },
    },
);

is $tx->render({ value => 'Xslate' }), "Hello, XSLATE world!\n";
is $tx->render({ value => 'Perl' }),   "Hello, PERL world!\n";

$tx = Text::Xslate->new(
    string => <<'TX',
Hello, <?= ucfirst(lc($value)) ?> world!
TX
    function => {
        lc      => sub{ lc $_[0] },
        ucfirst => sub{ ucfirst $_[0] },
    },
);

is $tx->render({ value => 'XSLATE' }), "Hello, Xslate world!\n";
is $tx->render({ value => 'PERL' }),   "Hello, Perl world!\n";

done_testing;
