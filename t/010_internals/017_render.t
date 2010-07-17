#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

unlink path . '/func.txc';
END{ unlink path . '/func.txc' }

my $tx = Text::Xslate->new(
    cache     => 1,
    cache_dir => path,
    path      => path,
    function  => { f => sub{ "[@_]" } },
);

is $tx->render('func.tx', { lang => 'Xslate' }),
    "Hello, [Xslate] world!\n";

$tx = Text::Xslate->new(
    cache     => 1,
    cache_dir => path,
    path      => path,
    function  => { f => sub{ "{@_}" } },
);

is $tx->render('func.tx', { lang => 'Xslate' }),
    "Hello, {Xslate} world!\n";

for(1 .. 2) {
    my $tx = Text::Xslate->new(cache => 0, path => [path]);
    isa_ok $tx, 'Text::Xslate', 'with list args';

    is $tx->render_string('Hello, <: $lang :> world!', { lang => 'Xslate' }),
        'Hello, Xslate world!';

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n";
}
done_testing;
