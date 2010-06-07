#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new(
    verbose => 2,
);

my @set = (
    # builtin filters
    ['<: $value | raw :>', { value => "<em>Xslate</em>" }, "<em>Xslate</em>", 'raw as a filter'],
    ['<: raw($value) :>',  { value => "<em>Xslate</em>" }, "<em>Xslate</em>", 'raw as a functiun'],

    ['<: $value | html :>', { value => "<Xslate>" }, "&lt;Xslate&gt;", 'html'],
    ['<: $value | dump :>', { value => "<Xslate>" }, qr/&lt;Xslate&gt;/, 'dump'],
    ['<: $value | dump | raw  :>', { value => "<Xslate>" }, qr/<Xslate>/, 'x | dump | raw'],

    ['<: $value | html | html :>', { value => "<Xslate>" }, "&lt;Xslate&gt;", 'x | html | html'],
    ['<: $value | html | raw  :>', { value => "<Xslate>" }, "&lt;Xslate&gt;", 'x | html | raw (-> html)'],
    ['<: $value | raw  | html :>', { value => "<Xslate>" }, "<Xslate>", 'x | raw | html (-> raw)'],

    ['<: html($value) == "&lt;Xslate&gt;" ? "true" : "false" :>',
        { value => '<Xslate>' }, 'true'],
    ['<: raw($value) == "&lt;Xslate&gt;" ? "true" : "false" :>',
        { value => '<Xslate>' }, 'false'],

    ['<: 1 ? raw($value) : html($value) :>',
        { value => '<Xslate>' }, '<Xslate>'],
    ['<: 1 ? html($value) : raw($value) :>',
        { value => '<Xslate>' }, '&lt;Xslate&gt;'],

    ['<: 0 ? raw($value) : html($value) :>',
        { value => '<Xslate>' }, '&lt;Xslate&gt;'],
    ['<: 0 ? html($value) : raw($value) :>',
        { value => '<Xslate>' }, '<Xslate>'],

    ['<: raw :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'raw itself'],
    ['<: html :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'html itself'],
);

foreach my $d(@set) {
    my($in, $vars, $expected, $msg) = @$d;
    if(ref $expected) {
        like $tx->render_string($in, $vars), $expected, $msg or diag $in;
    }
    else {
        is $tx->render_string($in, $vars), $expected, $msg or diag $in;
    }
}

done_testing;
