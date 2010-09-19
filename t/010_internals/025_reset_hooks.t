#!perl
use strict;
use warnings;

use Test::More tests => 20;
use Text::Xslate;

sub reset_diehook {
    local $SIG{__DIE__} = sub { die @_ };
    return 42;
}

sub reset_warnhook {
    local $SIG{__WARN__} = sub { warn @_ };
    return 42;
}

{
    my $tx = Text::Xslate->new(function => {
        reset_diehook  => \&reset_diehook,
        reset_warnhook => \&reset_warnhook,
    });

    for ( 1 .. 10 ) {
        is $tx->render_string( '[<: reset_diehook() :>]' ),  '[42]';
        is $tx->render_string( '[<: reset_warnhook() :>]' ), '[42]';
    }
}
