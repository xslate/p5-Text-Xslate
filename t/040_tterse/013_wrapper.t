#!perl -w
use strict;
use Test::More;

use lib "t/lib";
use TTSimple;

my @data = (
    [<<'T', <<'X'],
[% WRAPPER "wrapper.tt" -%]
Hello, [% lang %] world!
[% END -%]
T
------------------
Hello, Xslate world!
------------------
X

    [<<'T', <<'X'],
[% WRAPPER "wrapper_div.tt" -%]
Hello, [% lang %] world!
[% END -%]
T
<div class="wrapper">
Hello, Xslate world!
</div>
X


    [<<'T', <<'X'],
[% WRAPPER "hello.tt" -%]
[% END -%]
T
Hello, Xslate world!
X

    [<<'T', <<'X', 'WITH local vars'],
[% WRAPPER "hello.tt" WITH lang = "Perl" -%]
[% END -%]
T
Hello, Perl world!
X


    [<<'T', <<'X', 'macros outside wrapper'],
[% MACRO foo BLOCK %][% lang %][% END -%]
[% WRAPPER "wrapper.tt" -%]
Hello, [% foo() %] world!
[% END -%]
T
------------------
Hello, Xslate world!
------------------
X

    [<<'T', <<'X', 'macros inside wrapper'],
[% WRAPPER "wrapper.tt" -%]
[% MACRO foo BLOCK %][% lang %][% END -%]
Hello, [% foo() %] world!
[% END -%]
T
------------------
Hello, Xslate world!
------------------
X


    [<<'T', <<'X', 'INTO'],
[% WRAPPER "hello.tt" INTO lang %]TTerse[% END -%]
T
Hello, TTerse world!
X
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    last if $ENV{USE_TT} && defined($msg) and $msg eq 'INTO';

    my %vars = (lang => 'Xslate', foo => "<bar>", '$lang' => 'XXX');

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
