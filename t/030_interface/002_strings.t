#!perl -w
use strict;
use Test::More;

use Text::Xslate;

for(1 .. 2) {
    my $tx = Text::Xslate->new(
        string => "Hello, <?= \$lang ?> world!\n",
    );

    is $tx->render({ lang => 'Xslate' }), "Hello, Xslate world!\n", "string";
}

done_testing;
