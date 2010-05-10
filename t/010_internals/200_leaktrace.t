#!perl -w

use strict;

#use if $] == 5.010_000, 'Test::More', 'skip_all' => '5.10.0 has a bug about weak refs';
#use if $] != 5.010_001, 'Test::More', 'skip_all' => '(something is wrong; todo)';

use Test::Requires qw(Test::LeakTrace);
use Test::More;
use Text::Xslate;
use t::lib::Util;


my %vars = (
    lang  => 'Perl',
    my    => { lang => 'Xslate' },
    data  => [ { title => 'foo' }, { title => 'bar' } ],
    value => 32,
);

if(0) { # TODO
    no_leaks_ok {
        my $tx  = Text::Xslate->new(path => [path], cache => 0);
        my $out = $tx->render('hello.tx', \%vars);
        $out eq "Hello, Perl world!\n" or die "Error: [$out]";
    } "new() and render()" or die;
}

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

);

my $tx = Text::Xslate->new(
    path     => [path],
    cache    => 0,
    function => {
        uc => sub { uc $_[0] },
    },
);
foreach my $d(@set) {
    my($in, $out, $msg) = @$d;

    $tx->load_string($in);

    no_leaks_ok {
        my $o = $tx->render(undef, \%vars);

        $o eq $out or die "Error:\n[$o]\n[$out]";
    } $msg;
}

done_testing;
