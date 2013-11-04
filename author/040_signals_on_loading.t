#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use Time::HiRes qw(sleep alarm);

note $$;

for (1..10) {
    my $tx = Text::Xslate->new();

    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT" };
        alarm(0.010);
        $tx->render_string(q{: while true {} });
    };
    $@ =~ /TIMEOUT/ or note $@;
}

pass "program finished";

done_testing;
