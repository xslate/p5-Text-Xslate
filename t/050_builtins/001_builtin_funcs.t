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


    ['<: " foo " | uri :>', {}, '%20foo%20', 'x | uri'],
    ['<: "AZaz09-._~" | uri :>', {}, 'AZaz09-._~', 'RFC 3986' ],
    ['<: "/()\t" | uri :>', {}, '%2F%28%29%09' ],
    ['<: $s | uri :>', { s => ' ' x 255 }, '%20' x 255 ],
    ['<: (nil | uri) == nil ? "true" : "false" :>', {}, 'true' ],

    ['<: is_array_ref([]) ? 10 : 20 :>', {}, '10', 'is_array_ref'],
    ['<: is_array_ref({}) ? 10 : 20 :>', {}, '20', 'ref'],
    ['<: is_array_ref($v) ? 10 : 20 :>', {v => 42},       '20', 'ref'],
    ['<: is_array_ref($v) ? 10 : 20 :>', {v => bless []}, '20', 'ref'],

    ['<: is_hash_ref([]) ? 10 : 20 :>', {}, '20', 'ref'],
    ['<: is_hash_ref({}) ? 10 : 20 :>', {}, '10', 'ref'],
    ['<: is_hash_ref($v) ? 10 : 20 :>', {v => 42},       '20', 'ref'],
    ['<: is_hash_ref($v) ? 10 : 20 :>', {v => bless []}, '20', 'ref'],

    ['<: html($value) == "&lt;Xslate&gt;" ? "true" : "false" :>',
        { value => '<Xslate>' }, 'true'],
    ['<: raw($value) == "&lt;Xslate&gt;" ? "true" : "false" :>',
        { value => '<Xslate>' }, 'false'],

    ['<: $value | unmark_raw :>',       { value => '<Xslate>' }, "&lt;Xslate&gt;", 'unmark_raw' ],
    ['<: $value | raw | unmark_raw :>', { value => '<Xslate>' }, "&lt;Xslate&gt;", 'unmark_raw' ],

    ['<: 1 ? raw($value) : html($value) :>',
        { value => '<Xslate>' }, '<Xslate>'],
    ['<: 1 ? html($value) : raw($value) :>',
        { value => '<Xslate>' }, '&lt;Xslate&gt;'],

    ['<: 0 ? raw($value) : html($value) :>',
        { value => '<Xslate>' }, '&lt;Xslate&gt;'],
    ['<: 0 ? html($value) : raw($value) :>',
        { value => '<Xslate>' }, '<Xslate>'],

    ['<: for [raw($value)]  -> $i { :><: $i :><: } :>', { value => "<Xslate>" }, "<Xslate>" ],
    ['<: for [html($value)] -> $i { :><: $i :><: } :>', { value => "<Xslate>" }, "&lt;Xslate&gt;" ],

    ['<: raw :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'raw itself'],
    ['<: html :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'html itself'],

    ['<: mark_raw :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'mark_raw itself'],
    ['<: unmark_raw :>',
        { value => '<Xslate>' }, qr/\b CODE \b/xms, 'unmark_raw itself'],

    ['<: my $x = is_array_ref; $x([]) ? "ok" : "ng" :>', {}, 'ok', 'the entity of ref'],
    ['<: my $x = is_hash_ref;  $x({}) ? "ok" : "ng" :>', {}, 'ok', 'the entity of ref'],

    # with macros
    [<<'T', {}, <<'X'],
: macro foo -> {
    <br>
: }
: foo()
T
    <br>
X

    [<<'T', {}, <<'X'],
: macro foo -> {
    <br>
: }
: foo() | mark_raw
T
    <br>
X

    [<<'T', {}, <<'X'],
: macro foo -> {
    <br>
: }
: foo() | unmark_raw
T
    &lt;br&gt;
X

    [<<'T', {}, <<'X'],
: macro foo -> {
    <br>
: }
: foo() | unmark_raw | html
T
    &lt;br&gt;
X

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
