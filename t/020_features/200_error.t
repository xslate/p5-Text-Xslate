#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use t::lib::Util;

my $warn = '';
sub my_warn { $warn .= "@_" }

my $tx = Text::Xslate->new(
    warn_handler => \&my_warn,

    function => { f => sub{ die "DIE" } },
);

my $FILE = quotemeta(__FILE__);

foreach my $code(
    q{ nil },
    q{ nil.foo },
    q{ nil.foo() },
    q{ for nil -> ($item) { print "foobar"; } },
    q{ $h[nil] },
    q{ $a[nil] },
    q{ nil | raw },
    q{ nil | html },
) {
    $warn = '';

    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo'}, a => [42] });
    };

    is $out,  '', $code;
    is $warn, '';
    is $@,  '';
}


$warn = '';
my $out = eval {
    $tx->render_string("<: f() :>");
};

is $out, '', 'warn in render_string()';
like $warn, qr/DIE/, $warn;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';


note 'verbose => 2';

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
    q{ nil | raw },
    q{ nil | html },
) {
    $warn = '';
    my $out = eval {
        $tx->render_string("<: $code :>", { h => {'' => 'foo'}, a => [42] });
    };

    is $out,  '', $code;
    like $warn, qr/Use of nil/, $warn;
    like $warn, qr/at $FILE line \d+/;
    is $@,  '';
}

$warn = '';
$out = eval {
    $tx->render_string('<: $a + $b :>', { a => 'foo', b => 'bar' });
};

is $out, '0', 'warn in render_string()';
like $warn, qr/"foo" isn't numeric/;
like $warn, qr/"bar" isn't numeric/;
like $warn, qr/at $FILE line \d+/, 'warns come from the file';
is $@,  '';


done_testing;
