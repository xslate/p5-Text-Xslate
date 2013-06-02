#!/usr/bin/env perl
use strict;
use warnings;

use Text::Xslate;
use FindBin qw($Bin);

my $xslate = Text::Xslate->new({
    syntax    => 'TTerse',
    path      => "$Bin/tmpl",
    cache_dir => "$Bin/cache",
});

my @tmpls = qw/ contentA.tt contentB.tt /;
for my $tmpl (@tmpls) {
    print "\@\@$tmpl\n";
    print $xslate->render($tmpl);
}
