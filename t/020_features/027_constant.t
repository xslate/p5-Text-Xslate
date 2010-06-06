#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use t::lib::Util;

my $tx = Text::Xslate->new(
    path => [path],
    function => {
        format => sub{
            my($fmt) = @_;
            return sub { Text::Xslate::EscapedString->new(sprintf $fmt, @_) }
        },
    },
);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'literal'],
: constant FOO = 42
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
: constant FOO = 40 + 2
<: FOO :>
T
42
X


    [<<'T', { lang => 'Xslate' }, <<'X', 'var'],
: constant FOO = $lang
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
: constant make_em = format('<em>%s</em>')
    <: "foo" | make_em :>
    <: "bar" | make_em :>
T
    <em>foo</em>
    <em>bar</em>
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

    note $in;
    is $tx->render_string($in, $vars), $out,
        or diag($in);
}


done_testing;
