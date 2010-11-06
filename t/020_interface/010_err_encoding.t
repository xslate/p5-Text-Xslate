#!perl -w
use strict;
use Test::More;
use Text::Xslate;
use t::lib::Util;
use utf8;

my $warn = '';

my $tx = Text::Xslate->new(
    cache => 0,
    path  => [path],
    verbose => 2,
    warn_handler => sub {
        $warn .= "@_";
    },
);

like $tx->render('hello_utf8.tx'), qr/こんにちは/;
like $warn,                        qr/こんにちは/;

eval {
    $tx->render_string('<: こんにちは');
};
like $@, qr/<: こんにちは/;

done_testing;

