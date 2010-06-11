#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new();

sub add_one {
    my($x) = @_;
    return $x + 1;
}

my @set = (
    [<<'T', { data => [1 .. 3], add_one => \&add_one }, <<'X'],
<: $data.map($add_one).join(', ') :>
T
2, 3, 4
X

    [<<'T', { data => [1 .. 3], add_one => \&add_one }, <<'X'],
<: $data.reverse().map($add_one).join(', ') :>
T
4, 3, 2
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
: macro add_one -> $x { $x + 1 }
<: $data.map(add_one).join(', ') :>
T
2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
: macro add_one -> $x { $x + 1 }
: for $data -> $i {
    <: $data.map(add_one).join(', ') :>
: }
T
    2, 3, 4
    2, 3, 4
    2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
    <: $data.map(-> $x { $x + 1 }).join(', ') :>
T
    2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
<: $data.map(-> $x { $x + 1 }).join(', ') :>/<: $data.map(-> $x { $x + 2 }).join(', ') :>/<: $data.map(-> $x { $x + 3 }).join(', ') :>
T
2, 3, 4/3, 4, 5/4, 5, 6
X


    [<<'T', { data => [1 .. 3] }, <<'X'],
: for $data.map(-> $x { $x + 1 }) -> $v {
    [<: $v :>]
: }
T
    [2]
    [3]
    [4]
X

    [<<'T', { data => ['<foo>', '<bar>'] }, <<'X'],
: for $data.map(-> $x { $x }) -> $v {
    [<: $v :>]
: }
T
    [&lt;foo&gt;]
    [&lt;bar&gt;]
X
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}

# TODO(?): builtin methods in XS dies if callback dies, while
#          those in PP doesn't.
#foreach (1 .. 2) {
#    my $out = eval {
#        $tx->render_string(<<'T', { data => [1, 2, 3 ]});
#            : macro bad_macro -> $x { bad_macro($x) }
#            : $data.map(bad_macro).join(', ')
#            : "Hello"
#T
#    };
#    is $out, '';
#    like $@, qr/too deep/, 'callback died';
#    is $tx->render_string('Hello, world!'), 'Hello, world!', 'restart';
#}


done_testing;
