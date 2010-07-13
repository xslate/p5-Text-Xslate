#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T', 'Xslate' ],
    [%- lang -%]
T

    [<<'T', <<'X' ],
-    [%- lang -%]    -
T
-    Xslate    -
X

    [<<'T', <<'X' ],
    *
    [%- lang -%]
    *
T
    *Xslate    *
X

    [<<'T', <<'X' ],
    *

    [%- lang -%]

    *
T
    *
Xslate
    *
X

    [<<'T', <<'X' ],
    
    [%- lang -%]
    
T
    Xslate    
X

    [<<'T', <<'X' ],
    
    [%- lang -%]    
    
T
    Xslate    
X

    [<<'T', <<'X' ],
    
[%- lang -%]
    
T
    Xslate    
X

    [<<'T', <<'X' ],
    
[%- lang -%]    
    
T
    Xslate    
X

);

my %vars = (
    lang => 'Xslate',
    void => '',

    value => 10,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;
    is render_str($in, \%vars), $out, $msg or diag($in);
}

done_testing;
