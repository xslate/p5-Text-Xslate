#!perl
# reported by @kazeuro
# http://twitter.com/#!/kazeburo/status/55456855496994816
use strict;
use warnings;
use utf8;
use Text::Xslate;

use Test::More;

eval {
    local $SIG{__WARN__} = sub { die @_ };
    my $templates = {
        'index' => <<'EOF'
    <foo>ほげ<: $bar :></foo>
EOF
    };

    my $tx = Text::Xslate->new(
        path => [ $templates ],
    );
    $tx->render('index', { bar => 'ふが' } );
};

my $w = $@;
is $w, '' or diag $w;

done_testing;

