#!perl -w
use strict;
use Text::Xslate;

my $tx = Text::Xslate->new(
    path => 'author',
    cache => 0,
);

$tx->render('large.xml');

