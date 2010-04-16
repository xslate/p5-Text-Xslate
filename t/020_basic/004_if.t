#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['? if $lang {
ok
? }
? else {
not ok
? }
'
        => "ok\n"],

    ['? if !$lang {
ok
? }
? else {
not ok
? }
'
        => "not ok\n"],

    ['? if($lang){
ok
? }
? else {
not ok
? }
'
        => "ok\n"],

    ['? if(!$lang){
ok
? }
? else {
not ok
? }
'
        => "not ok\n"],


    ['? if $lang {
ok
? }
!'
        => "ok\n!"],

    ['? if $void {
ok
? }
!'
        => "!"],

    ['? if !$void {
ok
? }
!'
        => "ok\n!"],

    ['? if $lang {
a
? }
? else if $lang {
b
? }
!'
        => "a\n!"],

    ['? if !$lang {
a
? }
? else if $lang {
b
? }
!'
        => "b\n!"],

);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        lang => 'Xslate',
        void => '',

        value => 10,
    );
    is $x->render(\%vars), $out, 'first' or diag($in);
    is $x->render(\%vars), $out, 'second';
}

done_testing;
