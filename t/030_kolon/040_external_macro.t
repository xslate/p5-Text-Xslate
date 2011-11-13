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
: macro add10 -> $x { add($x, 10) }

: my $PI = 3.1415;
: macro PI -> { $PI }

: macro foo -> { nil }
T

'foo.tx' => <<'T',
: hello()
T
);

my $tx = Text::Xslate->new(
    path         => \%vpath,
    macro_module => ['macro/bar.tx'],
    cache        => 0,
    verbose      => 2,
    warn_handler => sub { die @_ },
);

if(1) {
    $tx->{compiler} = ref($tx->{compiler});
    note( dump($tx) );
}

is $tx->render('foo.tx'), "Hello, world!\n";
is $tx->render('foo.tx'), "Hello, world!\n";

is $tx->render_string(': add($foo, $bar)', { foo => 10, bar => 5 }), 15;
is $tx->render_string(': add($foo, $bar)', { foo =>  9, bar => 4 }), 13;

is $tx->render_string(': add10(20)'), 30;
is $tx->render_string(': add10(25)'), 35;

is $tx->render_string(': PI()' ), '3.1415';
is $tx->render_string(': PI()' ), '3.1415';

{
    local $@;
    eval{ $tx->render_string(': foo()') };
    like $@, qr/nil/;
}
done_testing;

