#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;
use Text::Xslate::Util qw(p);

my @data = (
    [<<'T', <<'X'],
[% SET i = 0 -%]
[% WHILE i < 3 -%]
    [% i %]
[% i = i + 1 -%]
[% END -%]
T
    0
    1
    2
X

    [<<'T', <<'X'],
[% SET i = 0 -%]
[% WHILE i < 3 -%]
    [% SET j = 10 -%]
    [% WHILE j < 12 -%]
        [% i %]-[% j %]
        [% j = j + 1 -%]
    [% END -%]
    [% i = i + 1 -%]
[% END -%]
T
        0-10
        0-11
        1-10
        1-11
        2-10
        2-11
X

    [<<'T', <<'X'],
[% set i = 0 -%]
[% while i < 3 -%]
    [% i %]
[% i = i + 1 -%]
[% end -%]
T
    0
    1
    2
X

    [<<'T', <<'X'],
[% set i = 0 -%]
[% while !(i == 3) -%]
    [% i %]
[% i = i + 1 -%]
[% end -%]
T
    0
    1
    2
X

    [<<'T', <<'X'],
[% set i = 0 -%]
[% while !!!(i == 3) -%]
    [% i %]
[% i = i + 1 -%]
[% end -%]
T
    0
    1
    2
X

    [<<'T', <<'X'],
[% set i = 0 -%]
[% while not(i == 3) -%]
    [% i %]
[% i = i + 1 -%]
[% end -%]
T
    0
    1
    2
X

);

my %vars = (lang => 'Xslate', foo => '<bar>', '$lang' => 'XXX');

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is join(' ', split ' ', render_str($in, \%vars)),
       join(' ', split ' ', $out), $msg
            or diag $in;
}

done_testing;
