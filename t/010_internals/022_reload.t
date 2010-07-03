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

done_testing;
