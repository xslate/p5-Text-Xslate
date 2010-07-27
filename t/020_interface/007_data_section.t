#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

use File::Path qw(rmtree);

rmtree(cache_dir);
END{ rmtree(cache_dir) }

my %vpath = (
    'foo.tx' => 'Hello, <: $lang :> world!',

    'base.tx'  => <<'T',
<html>
<body><: block body -> { :>default body<: } :></body>
</html>
T

    'child.tx' => <<'T',
: cascade base;
: override body -> {
child body
: } # endblock body
T
);

for my $cache(0 .. 2) {
    note "cache => $cache";
    my $tx = Text::Xslate->new(
        path      => [ \%vpath, path ],
        cache_dir => cache_dir,
        cache     => $cache,
    );

    is $tx->render('foo.tx', { lang => 'Xslate' }), 'Hello, Xslate world!', "(1)";
    is $tx->render('foo.tx', { lang => 'Perl' }),   'Hello, Perl world!',   "(2)";

    is $tx->render('child.tx'), <<'X' for 1 .. 2;
<html>
<body>child body
</body>
</html>
X

    is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "for real files";


    # reload
    local $vpath{'foo.tx'} = 'Modified';
    $tx = Text::Xslate->new(
        path      => \%vpath,
        cache_dir => cache_dir,
        cache     => $cache,
    );
    is $tx->render('foo.tx', { lang => 'Xslate' }), 'Modified', 'reloaded';
}

done_testing;
