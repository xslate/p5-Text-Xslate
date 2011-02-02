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
[% FOREACH i IN types -%]
[% FOREACH j IN types -%]
    * [[% i %]][[% j %]]
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


    [<<'T', <<'X', 'FOR-IN'],
[% lang %]
[% FOR type IN types -%]
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


    [<<'T', <<'X', 'loop.index'],
[% FOR type IN types -%]
* [% loop.index %]
[% END -%]
END
T
* 0
* 1
* 2
END
X

    [<<'T', <<'X', 'loop.index()'],
[% FOR type IN types -%]
* [% loop.index() %]
[% END -%]
END
T
* 0
* 1
* 2
END
X

    [<<'T', <<'X', 'loop.count'],
[% FOR type IN types -%]
* [% loop.count %]
[% END -%]
END
T
* 1
* 2
* 3
END
X

    [<<'T', <<'X', 'loop.first'],
[% FOR type IN types -%]
[% IF loop.first -%]
---- first ----
[% END -%]
* [% loop.count %]
[% END -%]
END
T
---- first ----
* 1
* 2
* 3
END
X

    [<<'T', <<'X', 'loop.last'],
[% FOR type IN types -%]
* [% loop.count %]
[% IF loop.last -%]
---- last ----
[% END -%]
[% END -%]
END
T
* 1
* 2
* 3
---- last ----
END
X


    [<<'T', <<'X', 'size'],
[% FOR type IN types -%]
* [% loop.size %]
[% END -%]
END
T
* 3
* 3
* 3
END
X

    [<<'T', <<'X', 'max'],
[% FOR type IN types -%]
* [% loop.max + 1 %]
[% END -%]
END
T
* 3
* 3
* 3
END
X

    [<<'T', <<'X', 'next'],
[% FOR type IN types -%]
* [% loop.next or "(none)" %]
[% END -%]
END
T
* Int
* Object
* (none)
END
X

    [<<'T', <<'X', 'prev'],
[% FOR type IN types -%]
* [% loop.prev or "(none)" %]
[% END -%]
END
T
* (none)
* Str
* Int
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

    [<<'T', <<'X', 'for-in'],
[% lang %]
[% for type in types -%]
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

    # ---- TTerse specific features ----

    [<<'T', <<'X', 'is_first && is_last', 1],
[% FOR type IN types -%]
[% IF loop.is_first -%]
---- first ----
[% END -%]* [% loop.count %]
[% IF loop.is_last -%]
---- last ----
[% END -%]
[% END -%]
END
T
---- first ----
* 1
* 2
* 3
---- last ----
END
X

    [<<'T', <<'X', 'peek_next'],
[% FOR type IN types -%]
* [% loop.peek_next or "(none)" %]
[% END -%]
END
T
* Int
* Object
* (none)
END
X

    [<<'T', <<'X', 'peek_prev'],
[% FOR type IN types -%]
* [% loop.peek_prev or "(none)" %]
[% END -%]
END
T
* (none)
* Str
* Int
END
X

    [<<'T', <<'X', 'nested'],
[%- FOR outer IN nested -%]
[% SET o_index = loop.index -%]
[% FOR elem IN outer -%]
[% o_index %].[% loop.index %]: [% elem %]
[% END -%]
END inner
[% END -%]
END
T
0.0: A1
0.1: A2
0.2: A3
END inner
1.0: B1
1.1: B2
1.2: B3
END inner
2.0: C1
2.1: C2
2.2: C3
END inner
END
X
);

foreach my $d(@data) {
    my($in, $out, $msg, $is_tterse_specific) = @$d;

    last if $is_tterse_specific && $ENV{USE_TT};

    my %vars = (
        lang => 'Xslate',
        types => [qw(Str Int Object)],
        nested => [
            [ qw( A1 A2 A3 ) ],
            [ qw( B1 B2 B3 ) ],
            [ qw( C1 C2 C3 ) ],
        ]
    );
    is render_str($in, \%vars), $out, $msg;
}

done_testing;
