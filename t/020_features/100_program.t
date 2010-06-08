#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @set = (
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

    [<<'T', { data => [42] }, 'bar', 'finish statement'],
<:
    block foo -> { print "bar" }
-:>
T
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
