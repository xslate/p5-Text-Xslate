#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();


my @data = (
    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx.yy.zz :>
T
42
X

    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx
    .yy.zz :>
T
42
X
    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx # comment
    .yy.zz :>
T
42
X

    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx.
    yy.zz :>
T
42
X

    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx. # comment
    yy.zz :>
T
42
X

    [ <<'T', { xx => { yy => { zz => 42 } } }, <<'X'],
<: $xx
    .
    yy
    .
    zz :>
T
42
X

    [ <<'T', { a => 10, b => 20, c => 30}, <<'X'],
<: $a
    + $b
    + $c :>
T
60
X

    [<<'T', { value => 10 }, <<'X'],
<:
    if($value == 10) {
        print "Hello, world!";
    }
    print "\n";
-:>
T
Hello, world!
X

    [<<'T', { data => [1, 2, 3] }, <<'X'],
<:
    for $data -> $item {
        print "[" ~ $item ~ "]";
    }
    print "\n";
-:>
T
[1][2][3]
X


    [<<'T', { data => 42 }, <<'X'],
<:
    given $data -> $it {
        default { print "[" ~ $it ~ "]"; }
    }
    print "\n";
-:>
T
[42]
X

    [<<'T', { data => [42] }, <<'X', 'block'],
<:
    for $data -> $it {
        if(1) { print "[" ~ $it ~ "]"; }
    }
    print "\n";
-:>
T
[42]
X

    [<<'T', { data => [42] }, <<'X', 'no last semicolon'],
<:
    block foo -> { "default value\n" }
-:>
T
default value
X

    [<<'T', { data => [42] }, '', 'empty block'],
<:
    block foo -> { }
-:>
T

    [<<'T', { data => [42] }, <<'X', 'no last semicolon'],
<:
    block foo -> { "default value\n" }
-:>
T
default value
X

    [<<'T', { data => [42] }, <<'X', 'finish statement'],
<:
    block foo -> { print "bar\n" }
-:>
T
bar
X

    [<<'T', { data => [42] }, <<'X', 'multi blocks'],
<:
    block foo -> { print "bar\n" }
    block bar -> { print "baz\n" }
-:>
T
bar
baz
X

);

foreach my $d(@data) {
    my($in, $vars, $out, $msg) = @$d;
    is eval { $tx->render_string($in, $vars) }, $out, $msg
        or diag $in;
}

done_testing;
