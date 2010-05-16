#!perl -w

use strict;
use Test::More;

use Text::Xslate::Util qw(literal_to_value);;

my @set = (
    [ q{"foo\\\\template"}, q{foo\template} ],

    [ q{"Hello, world\n"},  qq{Hello, world\n} ],
    [ q{"Hello, world\r"},  qq{Hello, world\r} ],

    [ q{'Hello, world\n'},  q{Hello, world\n} ],
    [ q{'Hello, world\r'},  q{Hello, world\r} ],
);

foreach my $d(@set) {
    my($in, $out) = @{$d};
    is literal_to_value($in), $out, $in;
}

done_testing;
