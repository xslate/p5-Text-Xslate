#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate::File;

use Time::HiRes qw(time);
use FindBin qw($Bin);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate)){
    print $mod, '/', $mod->VERSION, "\n";
}
my $path = "$Bin/template";

my $mt = Text::MicroTemplate::File->new(
    include_path => [$path],
    use_cache    => 2,
);
my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my %vars = (
    data => [
        ({ title => 'Programming Perl'}) x 100,
    ]
);
{
    my $out = $mt->render_file('list.mt', \%vars);
    $tx->render('list.tx', \%vars) eq $out or die $out;
}

$| = 1;

print "Text::MicrTemplate's render_file() x 1000\n";
my $start = time();
foreach (1 .. 1000) {
    print $_, "\r";
    my $out = $mt->render_file('list.mt', \%vars);
}
print "\n";
my $mt_used = time() - $start;
printf "Used: %.03f sec.\n", $mt_used;

print "Text::Xslate's render() x 1000\n";
$start = time();
foreach (1 .. 1000) {
    print $_, "\r";
    my $out = $tx->render('list.tx', \%vars);
}
print "\n";
my $tx_used = time() - $start;
printf "Used: %.03f sec.\n", $tx_used;

printf "In this benchmark, Xslate is about %.01f times faster than Text::MicroTemplate.\n",
    $mt_used / $tx_used;
