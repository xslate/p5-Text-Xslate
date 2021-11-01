#!perl -w
use strict;
use Test::More;
use Text::Xslate;

plan skip_all => 'disable on Windows with older perl(<5.14.2)' if $^O eq 'MSWin32' && $] < 5.014002;

my $tx = Text::Xslate->new();
$tx->render_string(''); # load related modules

eval {
    local $SIG{ALRM} = sub { die "TIMEOUT" };
    alarm(1);
    $tx->render_string(q{: while true {} });
};

like $@, qr/TIMEOUT/;

done_testing;
