#!perl -w
use 5.010_000;
use strict;

use Text::Xslate;
use Text::MicroTemplate::Extended;
use HTML::Template::Pro;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

use FindBin qw($Bin);

foreach my $mod(qw(Text::Xslate Text::MicroTemplate HTML::Template::Pro)){
    say $mod, '/', $mod->VERSION;
}

my $n = shift(@ARGV) || 1;

my @path = ("$Bin/template");
my $x  = Text::Xslate->new(
    path  => \@path,
    cache => 2,
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path => \@path,
    cache        => 2,
);
my $ht = HTML::Template->new(
    path           => \@path,
    filename       => "including.ht",
    case_sensitive => 1,
);

my %vars = (
     data => [(
        { title => 'Islands in the stream' },
        { title => 'Beautiful code' },
        { title => 'Introduction to Psychology' },
        { title => 'Programming Perl' },
        { title => 'Compilers: Principles, Techniques, and Tools' },
     ) x $n],
);

if($x->render('including.tx', \%vars) ne $mt->render('including', \%vars)) {
    print $x->render('including.tx', \%vars);
    print $mt->render('including',   \%vars);
}

#$ht->param(\%vars);die $ht->output();

print "Benchmarks for include commands\n";
# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$x->render('including.tx', \%vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->render('including', \%vars)];
        return;
    },
    ht => sub{
        $ht->param(\%vars);
        my $body = [$ht->output()];
        return;
    },
};
