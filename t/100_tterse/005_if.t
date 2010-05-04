#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T', <<'X', "if-end (true)"],
[% IF lang == "Xslate" -%]
    ok
[% END -%]
T
    ok
X

    [<<'T', <<'X', "if-end (false)"],
[% IF lang != "Xslate" -%]
    ok
[% END -%]
T
X

    [<<'T', <<'X', "if-else-end (true)"],
[% IF lang == "Xslate" -%]
    foo
[% ELSE -%]
    bar
[% END -%]
T
    foo
X

    [<<'T', <<'X', "if-else-end (false)"],
[% IF lang != "Xslate" -%]
    foo
[% ELSE -%]
    bar
[% END -%]
T
    bar
X

    [<<'T', <<'X', "if-elsif-end (1)"],
[% IF lang == "Xslate" -%]
    foo
[% ELSIF value == 10 -%]
    bar
[% ELSE -%]
    baz
[% END -%]
T
    foo
X

    [<<'T', <<'X', "if-elsif-end (2)"],
[% IF lang != "Xslate" -%]
    foo
[% ELSIF value == 10 -%]
    bar
[% ELSE -%]
    baz
[% END -%]
T
    bar
X

    [<<'T', <<'X', "if-elsif-end (false)"],
[% IF lang != "Xslate" -%]
    foo
[% ELSIF value != 10 -%]
    bar
[% ELSE -%]
    baz
[% END -%]
T
    baz
X

    [<<'T', <<'X', "unless-end (true)"],
[% UNLESS lang == "Xslate" -%]
    ok
[% END -%]
T
X

    [<<'T', <<'X', "unless-end (false)"],
[% UNLESS lang != "Xslate" -%]
    ok
[% END -%]
T
    ok
X

    [<<'T', <<'X', "nesting if"],
[% IF true %]
  one
[% END %]
[% IF false %]
  two
[% END %]
[% IF true %]
  [% IF true %]
    three
  [% END %]
  [% IF false %]
    four
  [% END %]
[% END %]
[% IF true %]
  five
[% END %]
[% IF false %]
  six
[% END %]
T

  one



  
    three
  
  


  five


X



);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = (
        lang => 'Xslate',
        void => '',

        value => 10,

        true  => 1,
        false => 0,
    );
    is render_str($in, \%vars), $out, $msg or diag($in);
}

done_testing;
