#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;
use Data::Dumper;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, <?= $lang ?> world!' => 'Hello, Xslate world!'],
    ['Hello, <?= $foo ?> world!' => 'Hello, &lt;bar&gt; world!'],
    ['<?= $lang ?> <?= $foo ?> <?= $lang ?> <?= $foo ?>' => 'Xslate &lt;bar&gt; Xslate &lt;bar&gt;'],
    [q{foo <?= $lang
        ?> bar} => "foo Xslate bar"],
    [q{<? print $lang ?>} => "Xslate"],
    [q{<?print $lang?>} => "Xslate"],
    [q{<?print $lang, "\n"?>} => "Xslate\n"],
    [q{<?print "<", $lang, ">"?>} => "&lt;Xslate&gt;"],
    [q{<?print_raw "<", $lang, ">"?>} => "<Xslate>"],

    ['<?= "foo\tbar\n" ?>', "foo\tbar\n"],
    [q{<?= 'foo\tbar\n' ?>}, 'foo\tbar\n'],
    [q{<?= ' & " \' ' ?>}, ' &amp; &quot; &#39; '],

    [q{foo<?# this is a comment ?>bar}, "foobar"],
    [q{<?=$lang?> foo<?# this is a comment ?>bar <?=$lang?>}, "Xslate foobar Xslate"],
    [q{foo<?
        ?>bar}, "foobar"],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (lang => 'Xslate', foo => "<bar>");

    my $vars_str = Dumper(\%vars);
    is $x->render(\%vars), $out, 'first';
    is $x->render(\%vars), $out, 'second';

    is Dumper(\%vars), $vars_str, 'vars are not changed';
}

done_testing;
