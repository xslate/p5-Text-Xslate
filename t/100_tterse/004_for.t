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

    # ---- TTerse specific features ----

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

    [<<'T', <<'X', 'is_first && is_last'],
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
);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    last if $msg eq 'lower cased' && $ENV{USE_TT};

    my %vars = (
        lang => 'Xslate',

        types => [qw(Str Int Object)],
    );
    is render_str($in, \%vars), $out, $msg;
}

done_testing;
