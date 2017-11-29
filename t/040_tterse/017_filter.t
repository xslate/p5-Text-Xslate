#!perl -w
use strict;
use Test::More;

BEGIN {
    %TTSimple::Func = (
        indent => \&mk_indent,
    );
}

use lib "t/lib";
use TTSimple;
use Text::Xslate::Util qw(p);

sub mk_indent {
    my($prefix) = @_;

    return sub {
        my($str) = @_;
        $str =~ s/^/$prefix/xmsg;
        return $str;
    }
}

my @data = (
    [<<'T', <<'X'],
<p>
[% FILTER html -%]
Hello, <Xslate> world!
[% END -%]
</p>
T
<p>
Hello, &lt;Xslate&gt; world!
</p>
X

    [<<'T', <<'X'],
<p>
[% FILTER html -%]
Hello, <Xslate> world!
[% END -%]
</p>
<p>
[% FILTER html -%]
Hello, <TTerse> world!
[% END -%]
</p>
T
<p>
Hello, &lt;Xslate&gt; world!
</p>
<p>
Hello, &lt;TTerse&gt; world!
</p>
X

    [<<'T', <<'X'],
<p>
[% filter html -%]
Hello, <Xslate> world!
[% END -%]
</p>
T
<p>
Hello, &lt;Xslate&gt; world!
</p>
X


    [<<'T', <<'X'],
<p>
[% filter mark_raw -%]
Hello, <Xslate> world!
[% END -%]
</p>
T
<p>
Hello, <Xslate> world!
</p>
X

    [<<'T', <<'X'],
<p>
[% filter unmark_raw -%]
Hello, <Xslate> world!
[% END -%]
</p>
T
<p>
Hello, &lt;Xslate&gt; world!
</p>
X

    [ <<'T', <<'X' ],
[% FILTER indent("| ") -%]
foo
bar
baz
[% END -%]
T
| foo
| bar
| baz
X

    [ <<'T', <<'X' ],
[% "foo\n" FILTER indent("| ") -%]
[% "bar\n" filter indent("| ") -%]
T
| foo
| bar
X

);

my %vars = (lang => 'Xslate', foo => { bar => 43 });

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
