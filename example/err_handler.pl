#!perl -w
use strict;
use Text::Xslate;
my %vpath = (
    hello => 'Hello, <: $lang :> world!' . "\n",
);
my $tx = Text::Xslate->new(
    cache        => 0,
    path         => \%vpath,
    verbose      => 2,
    warn_handler => sub { Text::Xslate->print('[[', @_, ']]') },
);

print $tx->render('hello', { lang => "Xslate" });
print $tx->render('hello', { });

