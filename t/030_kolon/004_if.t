#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    [': if $lang {
ok
: }
: else {
not ok
: }
'
        => "ok\n", "if-else"],

    [': if !$lang {
ok
: }
: else {
not ok
: }
'
        => "not ok\n"],

    [': if($lang){
ok
: }
: else {
not ok
: }
'
        => "ok\n"],

    [': if(!$lang){
ok
: }
: else {
not ok
: }
'
        => "not ok\n"],


    [': if $lang {
ok
: }
!'
        => "ok\n!"],

    [': if $void {
ok
: }
!'
        => "!"],

    [': if !$void {
ok
: }
!'
        => "ok\n!"],

    [': if $void { } else {
ok
: }
!'
        => "ok\n!"],

    [': if !$void {
Hello, <: $lang :> world!
: }
'
        => "Hello, Xslate world!\n"],

    [': if $void { } else {
Hello, <: $lang :> world!
: }
'
        => "Hello, Xslate world!\n"],


    [': if $lang {
a
: }
: else if $lang {
b
: }
!'
        => "a\n!"],

    [': if !$lang {
a
: }
: else if $lang {
b
: }
!'
        => "b\n!"],

    [<<'T', <<'X', "if-else-if-end (1)"],
: if $lang == "Xslate" {
    foo
: }
: else if $value == 10 {
    bar
: }
: else {
    baz
: }
T
    foo
X

    [<<'T', <<'X', "if-else-if-end (2)"],
: if $lang != "Xslate" {
    foo
: }
: else if $value == 10 {
    bar
: }
: else {
    baz
: }
T
    bar
X

    [<<'T', <<'X', "if-else-if-end (3)"],
: if $lang != "Xslate" {
    foo
: }
: else if $value != 10 {
    bar
: }
: else {
    baz
: }
T
    baz
X

    [<<'T', <<'X', "if-elsif-end (1)"],
: if $lang == "Xslate" {
    foo
: }
: elsif $value == 10 {
    bar
: }
: else {
    baz
: }
T
    foo
X

    [<<'T', <<'X', "if-elsif-end (2)"],
: if $lang != "Xslate" {
    foo
: }
: elsif $value == 10 {
    bar
: }
: else {
    baz
: }
T
    bar
X

    [<<'T', <<'X', "if-elsif-end (3)"],
: if $lang != "Xslate" {
    foo
: }
: elsif $value != 10 {
    bar
: }
: else {
    baz
: }
T
    baz
X

    [<<'T', <<'X', "if does not require parens"],
: if ($value + 10) == 20 {
    foo
: }
T
    foo
X

    [<<'T', <<'X', "if defined"],
: if defined $lang {
    foo
: }
T
    foo
X

    [<<'T', <<'X', "if not defined"],
: if not defined $undefined {
    foo
: }
T
    foo
X

    [<<'T', <<'X', "if not not defined"],
: if not not defined $lang {
    foo
: }
T
    foo
X

    [<<'T', <<'X', "if nil"],
: if $undefined == nil {
    foo
: }
T
    foo
X

    [<<'T', <<'X', "if not nil"],
: if not $value == nil {
    foo
: }
T
    foo
X

    [<<'T', <<'X'],
: if $value != nil and 1 {
    foo
: }
T
    foo
X

    [<<'T', <<'X'],
: if $value != nil or 1 {
    foo
: }
T
    foo
X

    [<<'T', <<'X'],
: if 1 and $value != nil {
    foo
: }
T
    foo
X

    [<<'T', <<'X'],
: if 0 or $value != nil {
    foo
: }
T
    foo
X

);

my %vars = (
    lang => 'Xslate',
    void => '',

    value => 10,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is $tx->render_string($in, \%vars), $out, $msg or diag $in;
}

done_testing;
