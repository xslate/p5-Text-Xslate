#!perl -w
use strict;
use Text::Xslate;
use Data::Dumper;
my $tx = Text::Xslate->new(cache => 2);

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Useqq  = 1;

foreach my $file(@ARGV) {
    my $asm = $tx->load_file($file);
    foreach my $c(@{$asm}) {
        print Dumper($c), "\n";
    }
}
