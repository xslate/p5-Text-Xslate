#!perl -w
use strict;
use Text::Xslate;

use UNIVERSAL(); # makes NYTProf happy

{
    package BlogEntry;
    use Mouse;
    has title => (is => 'rw');
    has body  => (is => 'rw');
}

my($cache, $n) = @ARGV;
$cache //= 1;
$n     //= 100;

my @blog_entries = map{ BlogEntry->new($_) } (
    {
        title => 'Entry one',
        body  => 'This is my first entry.',
    },
    {
        title => 'Entry two',
        body  => 'This is my second entry.',
    },
) x 10;
for(1 .. $n) {
    my $tx = Text::Xslate->new(
        path  => ["./benchmark/template"],
        cache => $cache,
    );

    $tx->render('child.tx', { blog_entries => \@blog_entries });
}

print $INC{'Text/Xslate/Compiler.pm'} ? "compiled.\n" : "cached.\n";
