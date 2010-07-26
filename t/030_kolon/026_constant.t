#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p mark_raw);
use t::lib::Util;

my $tx = Text::Xslate->new(
    path => [path],
    function => {
        format => sub{
            my($fmt) = @_;
            return sub { mark_raw(sprintf $fmt, @_) }
        },
    },
    verbose => 2,
);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'literal'],
: constant FOO = 42;
<: FOO :>
T
42
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'str'],
: constant FOO = "bar";
<: FOO :>
T
bar
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'expression'],
: constant FOO = 40 + 2;
<: FOO :>
T
42
X


    [<<'T', { lang => 'Xslate' }, <<'X', 'var'],
: constant FOO = $lang;
<: FOO :>
T
Xslate
X


    [<<'T', { lang => 'Xslate' }, <<'X', 'array'],
: constant FOO = ["foo", "bar"];
<: FOO[0] :>
<: FOO[1] :>
T
foo
bar
X

    [<<'T', { lang => 'Xslate' }, <<'X'],
: constant make_em = format('<em>%s</em>');
    <: "foo" | make_em :>
    <: "bar" | make_em :>
T
    <em>foo</em>
    <em>bar</em>
X

    [<<'T', { data => [qw(foo bar)] }, <<'X'],
: for $data -> $i {
    : constant ITEM  = $i;
    : constant INDEX = $~i.index;
    : constant COUNT = $~i.count;
    : constant BODY  = $~i.body;
    <: INDEX :> <: COUNT :> <: BODY[$~i] :> <: ITEM :>
: }
T
    0 1 foo foo
    1 2 bar bar
X

    [<<'T', { data => [qw(foo bar)] }, <<'X'],
: if (constant FOO = 42) != 42 {
    UNLIKELY
: }
: else {
    <: FOO :>
: }
T
    42
X

    [<<'T', { data => [qw(foo bar)] }, <<'X'],
: if (constant FOO = 42) != 42 {
    UNLIKELY
: }
: else {
    : constant FOO = 100;
    <: FOO :>
: }
T
    100
X

    [<<'T', { data => [qw(foo bar)] }, <<'X'],
: if (constant FOO = 42) != 42 {
    UNLIKELY
: }
: else {
    : constant FOO = 100;
    <: FOO :>
: }
T
    100
X

    [<<'T', { }, <<'X'],
<: macro make_em -> $x { :><em><: $x :></em><: } -:>
: constant EM = make_em;
<: EM("foo") :>
T
<em>foo</em>
X

    [<<'T', { }, <<'X'],
<: macro make_em -> $x { :><em><: $x :></em><: } -:>
: constant EM = [make_em];
<: EM[0]("foo") :>
T
<em>foo</em>
X

    [<<'T', { a => 'foo', b => 'bar' }, <<'X'],
<: macro foo -> { "foo" }
   macro bar -> { "bar" }
   constant DISPATCHER = {
       foo => foo,
       bar => bar,
   }; -:>
    <: DISPATCHER[$a]() :>
    <: DISPATCHER[$b]() :>
T
    foo
    bar
X

    [<<'T', { a => 'foo', b => 'bar' }, <<'X', 'constant after loop'],
<:  constant a = format('%d')(42);
    constant b = [format('%d')(43)];
    constant c = { d => 44 };
    macro foo -> $x { "    foo\n" }
    for [1] -> $y {
         foo($y) | format('%s');
    } -:>
    <: a :>
    <: b[0] :>
    <: c.d :>
T
    foo
    42
    43
    44
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);

    while($in =~ s/\b constant \s* (\w+)/my $1/xms) {
        my $name = $1;
        $in =~ s/\b \Q$name\E \b/\$$name/xmsg;
    }
    $in =~ /\$/ or die "Oops: $in";

    #note $in;
    is $tx->render_string($in, $vars), $out,
        or diag($in);
}


done_testing;
