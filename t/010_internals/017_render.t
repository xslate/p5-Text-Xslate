#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";
use Util;
use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

my $tx = Text::Xslate->new(
    cache     => 1,
    cache_dir => cache_dir,
    path      => path,
    function  => { f => sub{ "[@_]" } },
);

is $tx->render('func.tx', { lang => 'Xslate' }),
    "Hello, [Xslate] world!\n";

$tx = Text::Xslate->new(
    cache     => 1,
    cache_dir => cache_dir,
    path      => path,
    function  => { f => sub{ "{@_}" } },
);

is $tx->render('func.tx', { lang => 'Xslate' }),
    "Hello, {Xslate} world!\n";

for(1 .. 2) {
    my $tx = Text::Xslate->new({ cache => 0, path => [path] });
    isa_ok $tx, 'Text::Xslate', 'with HASH ref args';

    is $tx->render_string('Hello, <: $lang :> world!', { lang => 'Xslate' }),
        'Hello, Xslate world!';

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n";
}

rmtree(cache_dir);
for(1 .. 2) {
    # must not depend on global variables
    local $/ = '';
    local $\ = "\n";

    my $tx = Text::Xslate->new(
        cache     => 1,
        path      => [path],
        cache_dir => cache_dir,
    );
    isa_ok $tx, 'Text::Xslate', 'with list args';

    is $tx->render_string('Hello, <: $lang :> world!', { lang => 'Xslate' }),
        'Hello, Xslate world!';

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n";
}

done_testing;
