#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

{
    package ResultSet;
    use Mouse;

    has data => (
        is  => 'ro',
    );

    sub fetch {
        my($self) = @_;
        return shift @{$self->data};
    }
}

my @data = (
    [ <<'T', <<'X', "no loop" ],
: while $empty.fetch -> {
    [ok]
: }
T
X
    [ <<'T', <<'X', "no loop" ],
: while $empty.fetch -> $i {
    [<:$i:>]
: }
T
X

    [ <<'T', <<'X', "int array" ],
: while $foo.fetch -> $i {
    [<:$i:>]
: }
T
    [1]
    [2]
    [3]
    [4]
    [5]
X
    [ <<'T', <<'X', "record array" ],
: while $bar.fetch -> $item {
    [<:$item.title:>]
: }
T
    [A]
    [B]
    [C]
X
    [ <<'T', <<'X', "no loop vars" ],
: while $foo.fetch -> {
    [<:$x:>]
: }
T
    [42]
    [42]
    [42]
    [42]
    [42]
X

    [ <<'T', <<'X', "twice" ],
---
: while $foo.fetch ->($x) {
    [<:$x:>]
: }
---
: while $bar.fetch ->($x) {
    [<:$x.title:>]
: }
---
T
---
    [1]
    [2]
    [3]
    [4]
    [5]
---
    [A]
    [B]
    [C]
---
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my $x = $tx->compile_str($in);

    my %vars = (
        empty => ResultSet->new(data => []),
        foo => ResultSet->new(data => [1 .. 5]),
        bar => ResultSet->new(data => [
            { title => 'A' },
            { title => 'B' },
            { title => 'C' },
        ]),
        x => 42
    );
    is $x->render(\%vars), $out, $msg;
}

done_testing;
