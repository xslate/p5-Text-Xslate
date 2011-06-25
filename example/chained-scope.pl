#!perl
use strict;
use warnings;
use Text::Xslate;

my %vpath = (
    'foo.tx' => 'Hello, <: $a ~ $b :> world!' . "\n",
    'bar.tx' => ': include foo { __ROOT__.merge({ b => " with Kolon"}) }',
);

my $tx = Text::Xslate->new(
    cache => 0,
    path  => \%vpath,
);

print $tx->render('bar.tx', { a => 'Xslate' });

