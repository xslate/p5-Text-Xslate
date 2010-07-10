#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

END{ unlink '.test_data_section' }

my $section = {
    'foo.tx' => 'Hello, <: $lang :> world!',
};

for my $cache(0 .. 2) {
    my $tx = Text::Xslate->new(
        path      => [ $section, path ],
        cache_dir => '.test_data_section',
        cache     => $cache,
    );

    is $tx->render('foo.tx', { lang => 'Xslate' }), 'Hello, Xslate world!', "cache => $cache (1)";
    is $tx->render('foo.tx', { lang => 'Perl' }),   'Hello, Perl world!',   "cache => $cache (2)";

    is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "for files";
}

done_testing;
