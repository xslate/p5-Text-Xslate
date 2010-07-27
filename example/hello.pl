#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

my $path = $Bin;
my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir => '.eg_cache',
);

print $tx->render('hello.tx', { });
print $tx->render('hello.tx', { lang => "Xslate" });

