#!perl -w
use strict;
use Text::Xslate;

my $file = shift(@ARGV) or die "No templae file supplied";

my $tx = Text::Xslate->new(
    path => 'author',
    cache => 0,
);

$tx->render($file);

