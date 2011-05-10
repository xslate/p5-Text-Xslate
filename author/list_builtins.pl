#!perl -w
use strict;
use Text::Xslate;

my $tx = Text::Xslate->new();

print join("\n", sort keys %{ $tx->{function} }), "\n";

