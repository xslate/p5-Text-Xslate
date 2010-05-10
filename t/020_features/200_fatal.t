#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new();

eval {
    $tx->render_string('<: nil :>', {});
};

like $@, qr/uninitialized/, "Cannot print nil ($@)";
like $@, qr/Xslate/;

eval {
    $tx->render_string('<: "foo" + 0 :>', {});
};

like $@, qr/isn't numeric/, "Cannot numify a string ($@)"; # ' for poor editors
like $@, qr/Xslate/;


done_testing;
