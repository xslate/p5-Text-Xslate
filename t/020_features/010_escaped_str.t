#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(escaped_string);

my $x = Text::Xslate->new(string => 'Hello, <:= $lang :> world!');

is $x->render({ lang => '<Xslate>' }), 'Hello, &lt;Xslate&gt; world!';

is $x->render({ lang => Text::Xslate::EscapedString->new('&lt;Xslate&gt;') }),
    'Hello, &lt;Xslate&gt; world!', 'escaped';

is $x->render({ lang => escaped_string('&lt;Xslate&gt;') }),
    'Hello, &lt;Xslate&gt; world!', 'escaped';

is $x->render({ lang => escaped_string(escaped_string('&lt;Xslate&gt;')) }),
    'Hello, &lt;Xslate&gt; world!', 'double escaped';

is escaped_string('&lt;Xslate&gt;'), '&lt;Xslate&gt;', "escaped strings can be stringified";
cmp_ok escaped_string('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "escaped strings are comparable";

done_testing;
