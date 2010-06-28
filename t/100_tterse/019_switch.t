#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE "Xslate" -%]
    ok
[% CASE DEFAULT -%]
    unlikely
[% END -%]
T
    ok
X

    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE "Perl" -%]
    unlikely
[% CASE DEFAULT -%]
    ok
[% END -%]
T
    ok
X

    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE ["TTerse", "Xslate"] -%]
    ok
[% CASE DEFAULT -%]
    unlikely
[% END -%]
T
    ok
X

    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE "TTerse" -%]
    unlikely
[% CASE "Xslate" -%]
    ok
[% CASE DEFAULT -%]
    unlikely
[% END -%]
T
    ok
X

    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE "TTerse" -%]
    unlikely
[% CASE "Perl" -%]
    unlikely
[% END -%]
T
X


    [<<'T', <<'X' ],
[% SWITCH value -%]
[% CASE 10  -%]
    ok
[% END -%]
T
    ok
X

    [<<'T', <<'X' ],
[% SWITCH lang -%]
[% CASE DEFAULT -%]
    ok
[% END -%]
T
    ok
X

    [<<'T', <<'X', 'extra newline'],
[% SWITCH lang -%]

[% CASE "TTerse" -%]
    unlikely
[% CASE "Xslate" -%]
    ok
[% CASE DEFAULT -%]
    unlikely
[% END -%]
T
    ok
X

    [<<'T', <<'X', 'lower cased'],
[% switch lang -%]
[% case "TTerse" -%]
    unlikely
[% case "Xslate" -%]
    ok
[% case default -%]
    unlikely
[% end -%]
T
    ok
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = (
        lang => 'Xslate',
        void => '',

        value => 10,
    );
    is render_str($in, \%vars), $out, $msg or diag($in);
}

done_testing;
