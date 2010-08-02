#!perl -w
use strict;

use Text::Xslate;
use Template;

use Time::HiRes qw(time);
use FindBin qw($Bin);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Template)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $file = 'list.tt';

my $tt = Template->new(
    INCLUDE_PATH => ["$Bin/template"],
    COMPILE_EXT  => '.out',
);
my $tx = Text::Xslate->new(
    syntax    => 'TTerse',
    path      => ["$Bin/template"],
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my %vars = (
    data => [
        ({ title => 'Programming Perl'}) x 100,
    ]
);
{
    my $out;
    $tt->process($file, \%vars, \$out);
    $tx->render($file, \%vars) eq $out
        or die $tx->render($file, \%vars), "\n", $out;
}

$| = 1;

print "Template-Toolkit's process() x 1000\n";
my $start = time();
foreach (1 .. 1000) {
    print $_, "\r";
    $tt->process($file, \%vars, \my $out);
}
print "\n";
my $tt_used = time() - $start;
printf "Used: %.03f sec.\n", $tt_used;

print "Text::Xslate's render() x 1000\n";
$start = time();
foreach (1 .. 1000) {
    print $_, "\r";
    my $out = $tx->render($file, \%vars);
}
print "\n";
my $tx_used = time() - $start;
printf "Used: %.03f sec.\n", $tx_used;

printf "In this benchmark, Xslate is about %.01f times faster than Template-Tookit.\n",
    $tt_used / $tx_used;
