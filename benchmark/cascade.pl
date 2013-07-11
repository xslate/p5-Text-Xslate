#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate::Extended;

use Benchmark qw(:all);
use FindBin qw($Bin);
use Test::More;

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate Text::MicroTemplate::Extended)){
    print $mod, '/', $mod->VERSION, "\n";
}

my %args = @ARGV;

my $cache = defined($args{'--cache'}) ? $args{'--cache'} : 2;

{
    package BlogEntry;
    use Mouse;
    has title => (is => 'rw');
    has body  => (is => 'rw');
}
my $n = $args{'--size'} || 2;
my @blog_entries = map{ BlogEntry->new($_) } (
    {
        title => 'Entry one',
        body  => "This is my first entry.\n" x $n,
    },
    {
        title => 'Entry two',
        body  => "This is my second entry.\n" x $n,
    },
    {
        title => 'Entry three',
        body  => "This is my thrid entry.\n" x $n,
    },
    {
        title => 'Entry four',
        body  => "This is my forth entry.\n" x $n,
    },
    {
        title => 'Entry five',
        body  => "This is my fifth entry.\n" x $n,
    },
);

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir =>  '.xslate_cache',
    cache     =>  $cache,
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path  => [$path],
    template_args => { blog_entries => \@blog_entries },
    use_cache     => $cache,
);

{
    plan tests => 1;
    my $x = $tx->render('child.tx', { blog_entries => \@blog_entries });
    my $y = $mt->render('child');
    $x =~ s/\n//g;
    $y =~ s/\n//g;

    is $x, $y, "Xslate eq T::MT::Ex" or exit 1;
}

print "Benchmarks for template cascading\n";
cmpthese -1 => {
    MTEx => sub{ my $body = [ $mt->render('child') ] },
    TX   => sub{ my $body = [ $tx->render('child.tx', { blog_entries => \@blog_entries }) ] },
};
