#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate::Extended;
use HTML::Template::Pro;
use Template;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate HTML::Template::Pro Template)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 10;

my @path = ("$Bin/template");
my $tx  = Text::Xslate->new(
    path      => \@path,
    cache_dir => '.xslate_cache',
    cache     => 2,
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path => \@path,
    use_cache    => 2,
);
my $ht = HTML::Template->new(
    path           => \@path,
    filename       => "include.ht",
    case_sensitive => 1,
);
my $tt = Template->new(
    INCLUDE_PATH => \@path,
    COMPILE_EXT  => '.out',
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

{
    my $expected = $tx->render('include.tx', \%vars);
    $expected =~ s/\n+/\n/g;

    plan tests => 3;
    my $out = $mt->render('include', \%vars);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'MT - Text::MicroTemplate::Extended';

    $ht->param(\%vars);
    $out = $ht->output();
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'HT - HTML::Template::Pro';

    $out = '';
    $tt->process('include.tt', \%vars, \$out) or die $tt->error;
    is $out, $expected, 'TT - Template-Toolkit';
}

print "Benchmarks for include commands\n";
# suppose PSGI response body
cmpthese -1 => {
    Xslate => sub {
        my $body = [$tx->render('include.tx', \%vars)];
        return;
    },
    MT => sub {
        my $body = [$mt->render('include', \%vars)];
        return;
    },
    HT => sub {
        $ht->param(\%vars);
        my $body = [$ht->output()];
        return;
    },
    TT => sub {
        my $body = [''];
        $tt->process('include.tt', \%vars, \$body->[0]) or die $tt->error;
        return;
    },
};
