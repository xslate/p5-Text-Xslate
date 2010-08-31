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
        base       => '[% INCLUDE "header" %]Hello, [% content %] world!' . "\n",
        content     => 'Xslate',
    },
    header => ['wrap_begin'],
    footer => ['wrap_end'],
);

is $tx->render_string(q{Xslate}), <<'X';
Header
Hello, Xslate world!
X

is $tx->render('content'), <<'X';
Header
Hello, Xslate world!
X

done_testing;
