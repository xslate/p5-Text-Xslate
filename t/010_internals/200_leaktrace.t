#!perl -w

use strict;

use Test::Requires { 'Test::LeakTrace' => 0.13 };
use Test::More;
use Text::Xslate;
use Text::Xslate::Compiler;
use lib "t/lib";
use UtilNoleak;

#use if Text::Xslate->isa('Text::Xslate::PP'),
#    'Test::More' => skip_all => 'PP will be safe';

my %vars = (
    lang  => 'Perl',
    my    => { lang => 'Xslate' },
    data  => [ { title => 'foo' }, { title => 'bar' } ],
    value => 32,
);

no_leaks_ok {
    my $tx  = Text::Xslate->new(path => [path], cache => 0);
    my $out = $tx->render('hello.tx', \%vars);
    $out eq "Hello, Perl world!\n" or die "Error: [$out]";
} "new() and render()" or die;

my @set = (
    [<<'T', <<'X', 'interpolate'],
        Hello, <:= $my.lang :> world!
T
        Hello, Xslate world!
X

    [<<'T', <<'X', 'for'],
        : for $data -> ($item) {
            [<:= $item.title :>]
        : }
T
            [foo]
            [bar]
X

    [<<'T', <<'X', 'expr'],
        <:= ($value + 10) * 2 :>
T
        84
X

    [<<'T', <<'X', 'expr'],
        <:= ($value - 10) / 2 :>
T
        11
X

    [<<'T', <<'X', 'expr'],
        <:= $value % 2 :>
T
        0
X

    [<<'T', <<'X', 'expr'],
        <:= "|" ~ $my.lang ~ "|" :>
T
        |Xslate|
X

    [<<'T', <<'X', 'expr'],
        <:= $value > 10 ? "larger than 10" : "equal or smaller than 10" :>
T
        larger than 10
X

    [<<'T', <<'X', 'chained max'],
        <:= $value max 100 max 200 :>
T
        200
X

    [<<'T', <<'X', 'chainded min'],
        <:= $value min 100 min 200 :>
T
        32
X

    [<<'T', <<'X', 'filter'],
        <:= $my.lang | uc :>
T
        XSLATE
X

    [<<'T', <<'X', 'funcall'],
        <:= uc($my.lang) :>
T
        XSLATE
X

    [<<'T', <<'X', 'block'],
    : block hello -> {
        Hello, <: $my.lang :> world!
    : }
T
        Hello, Xslate world!
X

    [<<'T', <<'X', 'array literal'],
    : for ["Xslate", "Perl"] -> $i {
        Hello, <: $i :> world!
    : }
T
        Hello, Xslate world!
        Hello, Perl world!
X

    [<<'T', <<'X', 'hash literal'],
    Hello, <: ({ lang => "Xslate" }).lang :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'builtin method for $array.join()'],
    Hello, <: ['A', 'B', 'C'].join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for $array.reverse()'],
    Hello, <: ['C', 'B', 'A'].reverse().join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for $array.sort()'],
    Hello, <: ['C', 'B', 'A'].sort().join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for $array.sort()'],
    Hello, <: ['C', 'B', 'A'].sort(-> $a, $b { $a cmp $b }).join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for $array.map()'],
    Hello, <: ['A', 'B', 'C'].map(-> $x { "[" ~ $x ~ "]" }).join(" ") :> world!
T
    Hello, [A] [B] [C] world!
X

    [<<'T', <<'X', 'builtin method for $hash.values()'],
    Hello, <: ({ lang => "Xslate" }).values().join(",") :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'builtin method for $hash.keys()'],
    Hello, <: ({ "Xslate" => 42 }).keys().join(",") :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'builtin method for $hash.kv()'],
    Hello, <: ({ "Xslate" => 42 }).kv().map( -> $x { $x.key }).join(",") :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'high level functins'],
    <: [10, 20].count(-> $x { $x >= 10 }) :>
T
    2
X

);

my $tx = Text::Xslate->new(
    path     => [path],
    cache    => 0,
    function => {
        uc => sub { uc $_[0] },
        'array::count' => sub {
            my($a, $cb) = @_;
            return scalar grep { $cb->($_) } @{$a};
        },
    },
);
foreach my $d(@set) {
    my($in, $out, $msg) = @$d;

    $tx->load_string($in);

    no_leaks_ok {
        my $result = $tx->render('<string>', \%vars);

        $result eq $out or die <<"MSG"
Rendering Error
Expected: [$out]
Got:      [$result]
MSG
    } $msg;
}

done_testing;
