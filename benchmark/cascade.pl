#!perl -w
use strict;
use Text::Xslate;
use Text::MicroTemplate::Extended;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

use FindBin qw($Bin);
use Test::More;

{
    package BlogEntry;
    use Mouse;
    has title => (is => 'rw');
    has body  => (is => 'rw');
}

my @blog_entries = map{ BlogEntry->new($_) } (
    {
        title => 'Entry one',
        body  => 'This is my first entry.',
    },
    {
        title => 'Entry two',
        body  => 'This is my second entry.',
    },
    {
        title => 'Entry three',
        body  => 'This is my thrid entry.',
    },
    {
        title => 'Entry four',
        body  => 'This is my forth entry.',
    },
    {
        title => 'Entry five',
        body  => 'This is my fifth entry.',
    },
);

my $tx = Text::Xslate->new(
    path  => ["$Bin/template"],
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path  => ["$Bin/template"],
    template_args => { blog_entries => \@blog_entries },
);

{
    plan tests => 1;
    my $x = $tx->render('child.tx', { blog_entries => \@blog_entries });
    my $y = $mt->render('child');
    $x =~ s/\s//g;
    $y =~ s/\s//g;

    is $x, $y or exit 1;
}

print "Benchmarks for template cascading\n";
cmpthese -1 => {
    MT => sub{ my $body = [ $mt->render('child') ] },
    TX => sub{ my $body = [ $tx->render('child.tx', { blog_entries => \@blog_entries }) ] },
};
