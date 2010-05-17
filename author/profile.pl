#!perl -w
use strict;
use Text::Xslate;

{
    package BlogEntry;
    use Mouse;
    has title => (is => 'rw');
    has body  => (is => 'rw');
}

my $cache = shift(@ARGV) // 0;

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
for(1 .. 10) {
    my $tx = Text::Xslate->new(
        path  => ["./benchmark/template"],
        cache_dir => "./benchmark/template",
        cache => $cache,
    );

    $tx->render('child.tx', { blog_entries => \@blog_entries });
}
