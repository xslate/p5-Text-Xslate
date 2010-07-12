#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(
    verbose => 2,
    function => {
        uc => sub { uc $_[0] },
        tag => sub {
            my($tag) = @_;
            return sub {
                return "<$tag>\n@_</$tag>\n";
            };
        },
    },
);

my @set = (
    [<<'T', undef, <<'X'],
: macro div -> $content {
<div>
<: $content -:>
</div>
: }
: block main|div -> {
    Hello, world!
: }
T
<div>
    Hello, world!
</div>
X

    [<<'T', undef, <<'X'],
: block main|uc -> {
    Hello, world!
: }
T
    HELLO, WORLD!
X

    [<<'T', undef, <<'X'],
: block main | tag('p') -> {
    Hello, world!
: }
T
&lt;p&gt;
    Hello, world!
&lt;/p&gt;
X

    [<<'T', undef, <<'X'],
: block main | tag('p') | raw -> {
    Hello, world!
: }
T
<p>
    Hello, world!
</p>
X

    [<<'T', undef, <<'X', 'html filter does nothing'],
: block main | html -> {
    <em>Hello, world!</em>
: }
T
    <em>Hello, world!</em>
X

    [<<'T', undef, <<'X', 'use unmark_raw to apply html-escape'],
: block main | unmark_raw -> {
    <em>Hello, world!</em>
: }
T
    &lt;em&gt;Hello, world!&lt;/em&gt;
X

    [<<'T', undef, <<'X'],
: block main | raw -> {
    <em>Hello, world!</em>
: }
T
    <em>Hello, world!</em>
X

    [<<'T', undef, <<'X'],
: constant tag_p = tag('p');
: block main | tag_p | raw -> {
    Hello, world!
: }
T
<p>
    Hello, world!
</p>
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
