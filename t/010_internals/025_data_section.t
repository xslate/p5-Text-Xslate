#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

use File::Path qw(rmtree);
END{ rmtree '.test_data_section' }

my $data = {
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
};

for my $cache(0 .. 2) {
    my $tx = Text::Xslate->new(
        path      => [ $data, path ],
        cache_dir => '.test_data_section',
        cache     => $cache,
    );

    is $tx->render('foo.tx', { lang => 'Xslate' }), 'Hello, Xslate world!', "cache => $cache (1)";
    is $tx->render('foo.tx', { lang => 'Perl' }),   'Hello, Perl world!',   "cache => $cache (2)";

    is $tx->render('child.tx'), <<'X' for 1 .. 2;
<html>
<body>child body
</body>
</html>
X

    is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "for files";
}

done_testing;
