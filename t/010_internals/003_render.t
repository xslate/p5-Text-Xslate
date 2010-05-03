#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

for(1 .. 2) {
    my $tx = Text::Xslate->new(cache => 0, path => [path]);
    isa_ok $tx, 'Text::Xslate';

    is $tx->render_string('Hello, <: $lang :> world!', { lang => 'Xslate' }),
        'Hello, Xslate world!';

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n";

}

done_testing;
