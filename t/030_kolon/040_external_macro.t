#!perl -w
#
# global macros
#
use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(dump);

my %vpath = (
    'macro/bar.tx' => <<'T',
: macro hello -> {
Hello, world!
: }


: macro add -> $x, $y { $x + $y }

: my $PI = 3.1415;
: macro PI -> { $PI }

: my $CONFIG = { };
: macro CONFIG -> { $CONFIG }
T

'foo.tx' => <<'T',
: my $CONFIG = [];
: hello()
T
);

my $tx = Text::Xslate->new(
    path         => \%vpath,
    macro_module => ['macro/bar.tx'],
    cache        => 0,
    verbose      => 2,
);

is $tx->render('foo.tx'), "Hello, world!\n";
is $tx->render('foo.tx'), "Hello, world!\n";

is $tx->render_string(': add($foo, $bar)', { foo => 10, bar => 5 }), 15;
is $tx->render_string(': add($foo, $bar)', { foo =>  9, bar => 4 }), 13;

is $tx->render_string(': PI()' ), '3.1415';
is $tx->render_string(': PI()' ), '3.1415';

# XXX: SEGV at Text-Xslate.xs:1649
#      because CONFIG's st is different from the main
# diag $tx->render_string(': CONFIG()');
done_testing;

