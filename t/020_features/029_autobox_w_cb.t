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

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}

done_testing;
