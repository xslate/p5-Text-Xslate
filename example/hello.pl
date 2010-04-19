#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

my $tx = Text::Xslate->new(
    file  => 'hello.tx',
    path  => ["$Bin/template"],
);

print $tx->render({ lang => "Xslate" });

