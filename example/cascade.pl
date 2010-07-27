#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

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
);

my $path = $Bin;
my $tx = Text::Xslate->new(
    path      => [$path],
    cache_dir =>  '.eg_cache',
);

print $tx->render('cascade.tx', { blog_entries => \@blog_entries });
