#!perl
# reported by @kazeuro
# http://twitter.com/#!/kazeburo/status/55456855496994816
use strict;
use warnings;
use utf8;
use Text::Xslate;
use Encode qw(encode_utf8);

use Test::More tests => 5;

use t::lib::Util qw(path);


eval {
    local $SIG{__WARN__} = sub { die @_ };
    my $templates = {
        'index' => encode_utf8(<<'EOF'),
    <foo>ほげ<: $bar :></foo>
EOF
    };

    my $tx = Text::Xslate->new(
        path => [ $templates ],
        cache_dir => path,
    );
    ok $tx->render('index', { bar => 'ふが' } ), '1-1';
    ok $tx->render('index', { bar => 'ふが' } ), '1-2';

    $tx = Text::Xslate->new(
        path => [ $templates ],
        cache_dir => path,
    );
    ok $tx->render('index', { bar => 'ふが' } ), '2-1';
    ok $tx->render('index', { bar => 'ふが' } ), '2-2';
};

my $w = $@;
is $w, '' or diag $w;

done_testing;

