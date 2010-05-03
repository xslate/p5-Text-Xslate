#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Tie::Array;
use Tie::Hash;

my @a;
tie @a, 'Tie::StdArray';

my $tx = Text::Xslate->new();

my $tmpl = <<'T';
: for $data ->($item) {
    [<:=$item.first:>][<:=$item.second:>]
: }
T

@a = (
    { first => 'foo',  second => 'bar' },
    { first => 'hoge', second => 'fuga' },
);

is $tx->render_string($tmpl, { data => \@a }), <<'X', "tied array" for 1 .. 2;
    [foo][bar]
    [hoge][fuga]
X

@a = (
    { first => 'aaa', second => 'bbb' },
    { first => 'ccc', second => 'ddd' },
);
my %h;
tie %h, 'Tie::StdHash';

%h = (data => \@a);

is $tx->render_string($tmpl, \%h), <<'T', "tied hash" for 1 .. 2;
    [aaa][bbb]
    [ccc][ddd]
T

done_testing;
