#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(
    cache  => 0,
    syntax => 'TTerse',
    path => {
        wrap_begin => '[% WRAPPER "base" %]',
        wrap_end   => '[% END %]',

        header     => 'Header' . "\n",
        base       => '[% INCLUDE "header" %]Hello, [% content %] world!',
        content     => 'Xslate',
    },
    header => ['wrap_begin'],
    footer => ['wrap_end'],
);

is $tx->render('content'), "Header\nHello, Xslate world!";

done_testing;
