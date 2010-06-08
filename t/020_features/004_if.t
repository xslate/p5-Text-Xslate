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

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = (
        lang => 'Xslate',
        void => '',

        value => 10,
    );
    is $tx->render_string($in, \%vars), $out, $msg or diag($in);
}

done_testing;
