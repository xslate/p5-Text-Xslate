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


    [<<'T', <<'X', 'loop.odd'],
[% FOR type IN types -%]
* [% loop.odd %]
[% END -%]
END
T
* 1
* 0
* 1
END
X

    [<<'T', <<'X', 'loop.even'],
[% FOR type IN types -%]
* [% loop.even %]
[% END -%]
END
T
* 0
* 1
* 0
END
X

    [<<'T', <<'X', 'loop.parity'],
[% FOR type IN types -%]
* [% loop.parity %]
[% END -%]
END
T
* odd
* even
* odd
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

    [<<'T', <<'X', 'FOR-IN'],
[% lang %]
[% FOR type IN types -%]
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
