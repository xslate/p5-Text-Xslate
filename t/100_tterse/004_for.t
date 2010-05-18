#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T', <<'X', 'once'],
[% lang %]
[% FOREACH type IN types -%]
* [% type %]
[% END -%]
END
T
Xslate
* Str
* Int
* Object
END
X

    [<<'T', <<'X', 'twice'],
[% lang %]
[% FOREACH type IN types -%]
    * [% type %]
[% END -%]
[% FOREACH type IN types -%]
    + [% type %]
[% END -%]
END
T
Xslate
    * Str
    * Int
    * Object
    + Str
    + Int
    + Object
END
X

    [<<'T', <<'X', 'nested'],
BEGIN
[% FOREACH x IN types -%]
[% FOREACH y IN types -%]
    * [[% x %]][[% y %]]
[% END -%]
[%- END -%]
END
T
BEGIN
    * [Str][Str]
    * [Str][Int]
    * [Str][Object]
    * [Int][Str]
    * [Int][Int]
    * [Int][Object]
    * [Object][Str]
    * [Object][Int]
    * [Object][Object]
END
X

    [<<'T', <<'X', 'lower cased'],
[% lang %]
[% foreach type in types -%]
* [% type %]
[% end -%]
END
T
Xslate
* Str
* Int
* Object
END
X
);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = (
        lang => 'Xslate',

        types => [qw(Str Int Object)],
    );
    is render_str($in, \%vars), $out, $msg;
}

done_testing;
