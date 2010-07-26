#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my %vars = (
    xx    => { yy => { zz => 42 } },
    value => 10,
    data  => [1, 2, 3],
    a     => 10,
    b     => 20,
    c     => 30,
);

my @data = (
    [ <<'T', <<'X'],
<: $xx.yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx
    .yy.zz :>
T
42
X
    [ <<'T', <<'X'],
<: $xx # comment
    .yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx.
    yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx. # comment
    yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx
    .
    yy
    .
    zz :>
T
42
X

    [ <<'T', <<'X'],
<: $a
    + $b
    + $c :>
T
60
X

    [<<'T', <<'X'],
<:
    if($value == 10) {
        print "Hello, world!";
    }
    print "\n";
-:>
T
Hello, world!
X

    [<<'T', <<'X'],
<:
    for $data -> $item {
        print "[" ~ $item ~ "]";
    }
    print "\n";
-:>
T
[1][2][3]
X


    [<<'T', <<'X'],
<:
    given $value -> $it {
        default { print "[" ~ $it ~ "]"; }
    }
    print "\n";
-:>
T
[10]
X

    [<<'T', <<'X', 'block'],
<:
    for [$value] -> $it {
        if(1) { print "[" ~ $it ~ "]"; }
    }
    print "\n";
-:>
T
[10]
X

    [<<'T', <<'X', 'no last semicolon'],
<:
    block foo -> { "default value\n" }
-:>
T
default value
X

    [<<'T', '', 'empty block'],
<:
    block foo -> { }
-:>
T

    [<<'T', <<'X', 'no last semicolon'],
<:
    block foo -> { "default value\n" }
-:>
T
default value
X

    [<<'T', <<'X', 'finish statement'],
<:
    block foo -> { print "bar\n" }
-:>
T
bar
X

    [<<'T', <<'X', 'multi blocks'],
<:
    block foo -> { print "bar\n" }
    block bar -> { print "baz\n" }
-:>
T
bar
baz
X

    [<<'T', <<'X'],
<:
    my $a = [
        10,
        20,
        30,
    ];
    print $a[0], "\n";
    print $a[1], "\n";
    print $a[2], "\n";
-:>
T
10
20
30
X

    [<<'T', <<'X'],
<:
    my $h = {
        foo => 10,
        bar => 20,
        baz => 30,
    };
    print $h.foo, "\n";
    print $h.bar, "\n";
    print $h.baz, "\n";
-:>
T
10
20
30
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;
    is eval { $tx->render_string($in, \%vars) }, $out, $msg
        or diag $in;
}

done_testing;
