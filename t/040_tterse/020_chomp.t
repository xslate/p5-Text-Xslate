#!perl -w
use strict;
use Test::More;

use lib "t/lib";
use TTSimple;

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


    # http://github.com/gfx/p5-Text-Xslate/issues#issue/12
    #['Hello, [%~ "Xslate" ~%] world!', 'Hello,Xslateworld!'],
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
