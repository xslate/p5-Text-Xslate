#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();
$tx->render_string(''); # load related modules

eval {
    local $SIG{ALRM} = sub { die "TIMEOUT" };
    alarm(1);
    $tx->render_string(q{: while true {} });
};

like $@, qr/TIMEOUT/;

done_testing;
