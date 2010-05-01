#!perl -w
use strict;
use Test::More;

use Text::Xslate;

use FindBin qw($Bin);

sub mk_indent {
    my($prefix) = @_;

    return sub {
        my($str) = @_;
        $str =~ s/^/$prefix/xmsg;
        return $str;
    }
}

my $tx = Text::Xslate->new(
    string => <<'TX',
<:= $value | indent("> ") :>
TX
    function => {
        indent => \&mk_indent,
    },
);

is $tx->render({ value => 'Xslate' }), "&gt; Xslate\n";
is $tx->render({ value => 'Perl' }),   "&gt; Perl\n";

$tx = Text::Xslate->new(
    string => <<'TX',
:= $value | indent("| ")
TX
    function => {
        indent => \&mk_indent,
    },
);

is $tx->render({ value => "foo\nbar\n" }),  <<'T', 'dynamic filters using |';
| foo
| bar
T

is $tx->render({ value => "foo\nbar\nbaz\n" }),  <<'T';
| foo
| bar
| baz
T

$tx = Text::Xslate->new(
    string => <<'TX',
:= indent("+ ")($value)
TX
    function => {
        indent => \&mk_indent,
    },
);

is $tx->render({ value => "foo\nbar\n" }),  <<'T', 'dynamic filters using ()';
+ foo
+ bar
T

is $tx->render({ value => "foo\nbar\nbaz\n" }),  <<'T';
+ foo
+ bar
+ baz
T

done_testing;
