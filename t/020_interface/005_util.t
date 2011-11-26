#!perl -w
use strict;
use Test::More;

use Text::Xslate::Util qw(
    literal_to_value
    value_to_literal
    read_around
    html_builder
    uri_escape
    html_escape
    mark_raw
    unmark_raw
);

my @set = (
    [ q{"foo\\\\template"}, q{foo\template} ],

    [ q{"Hello, world\n"},  qq{Hello, world\n} ],
    [ q{"Hello, world\r"},  qq{Hello, world\r} ],
    [ q{"Hello, world\t"},  qq{Hello, world\t} ],

    [ q{'Hello, world\n'},  q{Hello, world\n} ],
    [ q{'Hello, world\r'},  q{Hello, world\r} ],
    [ q{'Hello, world\t'},  q{Hello, world\t} ],

    [ q{foobar},  q{foobar} ],
    [ q{foo_bar}, q{foo_bar} ],

    [ q{010},  010 ],
    [ q{0x10}, 0x10 ],
    [ q{0b10}, 0b10 ],

    [ q{-010},  -010 ],
    [ q{-0x10}, -0x10 ],
    [ q{-0b10}, -0b10 ],

    [ q{+010},  +010 ],
    [ q{+0x10}, +0x10 ],
    [ q{+0b10}, +0b10 ],

    [ q{010_10},   010_10 ],
    [ q{0x10_10}, 0x10_10 ],
    [ q{0b10_10}, 0b10_10 ],

    [ q{0xDeadBeef}, 0xDeadBeef ],

    [ q{"+10"},   "+10" ],
    [ q{"+10.0"}, "+10.0" ],
    [ q{"-10"},   "-10" ],
    [ q{"-10.0"}, "-10.0" ],

    [ q{"01"},   "01" ],
    [ q{"00"},   "00" ],
    [ q{"010"}, "010" ],

    [q{'test="test"'},q{test="test"}],
    [q{"test='test'"},q{test='test'}],
);

foreach my $d(@set) {
    my($in, $out) = @{$d};
    my $v = literal_to_value($in);
    is $v, $out, "literal: $in";
    is literal_to_value(value_to_literal($v)), $out;
}

# 0 must be a number
is value_to_literal( '0'), q{0};
is value_to_literal( '1'), q{1};
is value_to_literal('10'), q{10};
is value_to_literal('00'), q{"00"};
is value_to_literal('01'), q{"01"};

# other utils

is read_around(__FILE__, 1), <<'X', 'read_around';
#!perl -w
use strict;
X

is read_around(__FILE__, 1, 2), <<'X', 'read_around';
#!perl -w
use strict;
use Test::More;
X

#foo
#bar
#baz
is read_around(__FILE__, __LINE__ - 2), <<'X', 'read_around';
#foo
#bar
#baz
X

is read_around(__FILE__ . "__unlikely__", 1), <<'X', 'read_around';
X

is read_around(undef, undef), <<'X', 'read_around';
X

# html escaping

is     mark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;', "raw strings can be stringified";
cmp_ok mark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "raw strings are comparable";

is     unmark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;';
cmp_ok unmark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;';

is html_escape(q{ & ' " < > }),  qq{ &amp; &#39; &quot; &lt; &gt; }, 'html_escape()'; # '
is html_escape('<Xslate>'), '&lt;Xslate&gt;', 'html_escape()';
is html_escape(html_escape('<Xslate>')), '&lt;Xslate&gt;', 'duplicated html_escape()';

{ # for MAGICs
    local $1;
    "<foo>" =~ /(.+)/;
    is html_escape($1), '&lt;foo&gt;', 'html_escape($1)';
}

my $hb = html_builder { "<br />" };
is $hb->(), "<br />";
$hb = html_builder {
    my($x, $y) = @_;
    return sprintf "<%d>", $x + $y;
};
is $hb->(1, 2), "<3>";
$hb = html_builder {
    my($x, $y) = @_;
    return sprintf "%s%s", html_escape($x), html_escape($y);
};
is $hb->('<br>', mark_raw('<br>')), "&lt;br&gt;<br>";

# uri_escape

is uri_escape(undef), undef;
is uri_escape(""), "";
is uri_escape("abc"), "abc";
is uri_escape("\0foo\0"), "%00foo%00";

# it encodes the arg as UTF-8 if perl string is passed
is uri_escape(qq{"Camel" is \x{99F1}\x{99DD} in Japanese}),
               q{%22Camel%22%20is%20%E9%A7%B1%E9%A7%9D%20in%20Japanese};

# it doesn't touch the encoding of the arg if byte stream is passed
is uri_escape("\xE9p\xE9k"), q{%E9p%E9k}; # "camel" in Japanese kanji (Shift_JIS)

is uri_escape("AZaz09-._~"), "AZaz09-._~";
is uri_escape(q{'foo'}), '%27foo%27';
is uri_escape(q{"bar"}), '%22bar%22';

my $x = 'foo/bar';
is uri_escape($x), 'foo%2Fbar';
is $x,             'foo/bar';

{ # for MAGICs
    local $1;
    $x =~ /(.+)/;
    is uri_escape($1), 'foo%2Fbar', 'uri_escape($1)';
}

done_testing;
