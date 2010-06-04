#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;
use Text::Xslate::Util qw(p);

my @data = (
    [<<'T', <<'X'],
[% SET lang = 'TTerse' -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
X

    [<<'T', <<'X'],
[% SET lang = 'TTerse', foo = "bar" -%]
Hello, [% lang %] world!
Hello, [% foo %] world!
T
Hello, TTerse world!
Hello, bar world!
X

    [<<'T', <<'X'],
[% SET a = 10
       b = 20
       c = 30

-%]
a = [% a %]
b = [% b %]
c = [% c %]
T
a = 10
b = 20
c = 30
X



    [<<'T', <<'X', 'lower cased'],
[% set lang = 'TTerse' -%]
Hello, [% lang %] world!
T
Hello, TTerse world!
X

);

my %vars = (lang => 'Xslate', foo => "<bar>", '$lang' => 'XXX');
my $orig = p(\%vars);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    last if $ENV{USE_TT} && defined($msg) and $msg eq 'lower cased';

    is render_str($in, \%vars), $out, $msg
        or diag $in;

    is p(\%vars), $orig, '%vars is not changed';
}

done_testing;
