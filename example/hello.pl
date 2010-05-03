#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

my $tx = Text::Xslate->new(
    path  => ["$Bin/template"],
);

print $tx->render('hello.tx', { });
print $tx->render('hello.tx', { lang => "Xslate" });

