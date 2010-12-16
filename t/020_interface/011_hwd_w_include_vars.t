#!perl
use strict;
use warnings;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(hash_with_default);

my $tx = Text::Xslate->new(
    path => [{ 'dish.tx' => '{[% food %]}' } ],
    cache => 0,
    syntax => 'TTerse',
    verbose => 2,
   );

my $_var = { food => 'rakkyo' };
my $var;
my $tmpl =<<EOTMPL;
[%- food = 'gyoza' -%]
[%- IF food -%]
[%- INCLUDE "dish.tx" WITH food = food -%]
[%- END -%]
EOTMPL

$var = $_var;
is $tx->render_string($tmpl, $var), '{gyoza}';

$var = hash_with_default($_var, sub { qq{*FILLME ($_[0])*} });
is $tx->render_string($tmpl, $var), '{gyoza}';

done_testing;

