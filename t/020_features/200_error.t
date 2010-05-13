#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $warn = '';
sub my_warn { $warn .= "@_" }

my $tx = Text::Xslate->new(
    warn_handler => \&my_warn,
);

foreach my $code(
    q{ nil },
    q{ nil.foo },
    q{ nil.foo() },
    q{ for nil -> ($item) { print "foobar"; } },
    q{ $h[nil] },
    q{ $a[nil] },
) {
    $warn = '';

    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo'}, a => [42] });
    };

    is $out,  '', $code;
    is $warn, '';
    is $@,  '';
}

$tx = Text::Xslate->new(
    verbose      => 2,
    warn_handler => \&my_warn,
);

foreach my $code(
    q{ nil },
    q{ nil.foo },
    q{ nil.foo() },
    q{ for nil -> ($item) { print "foobar"; } },
    q{ $h[nil] },
    q{ $a[nil] },
) {
    $warn = '';
    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo'}, a => [42] });
    };

    is $out,  '', $code;
    like $warn, qr/Use of nil/, $warn;
    is $@,  '';
}

done_testing;
