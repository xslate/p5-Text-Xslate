#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;
use Text::Xslate::Util qw(p);

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

);

my %vars = (lang => 'Xslate', foo => { bar => 43 });

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
