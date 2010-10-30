#!perl -w
use strict;
use Text::Xslate;

my %template = (
    'base' => <<'T',
: block hello -> {
    Hello, <: inner :>!
: }
T

    'child' => <<'T',
: cascade 'base'
: augment hello -> { "Augment" }
T
);

my $tx = Text::Xslate->new(
    path => \%template,
    cache => 0,
);
print $tx->render('child');
