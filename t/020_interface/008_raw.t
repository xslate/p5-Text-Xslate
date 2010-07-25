#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(mark_raw unmark_raw html_escape escaped_string);

is     escaped_string('&lt;Xslate&gt;'),       '&lt;Xslate&gt;', "raw strings can be stringified";
cmp_ok escaped_string('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "raw strings are comparable";

is     mark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;', "raw strings can be stringified";
cmp_ok mark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "raw strings are comparable";

is     unmark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;';
cmp_ok unmark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;';

is html_escape(q{ & ' " < > }),  qq{ &amp; &apos; &quot; &lt; &gt; }, 'html_escape()';
is html_escape('<Xslate>'), '&lt;Xslate&gt;', 'html_escape()';
is html_escape(html_escape('<Xslate>')), '&lt;Xslate&gt;', 'duplicated html_escape()';

is html_escape("<") . "Xslate" . html_escape(">"), "&lt;Xslate&gt;";
is html_escape(html_escape("<") . "Xslate" . html_escape(">")), "&lt;Xslate&gt;";

my $s = html_escape("&");
is $s . " foo", "&amp; foo";
is $s, "&amp;";
is "foo " . $s . " bar", "foo &amp; bar";
is $s, "&amp;";

$s .= "&";
is $s, "&amp;&amp;";
is html_escape($s), "&amp;&amp;";
is html_escape(unmark_raw($s)), "&amp;amp;&amp;amp;";

done_testing;
