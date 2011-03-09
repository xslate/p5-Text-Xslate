#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
    foo => ': include "bar" { $baz }',
    bar => 'Hello, <: $lang :> world!',
);

my $tx = Text::Xslate->new(cache => 0, path => \%vpath, verbose => 2);

is $tx->render(foo => { baz => { lang => 'Xslate' } }),
    'Hello, Xslate world!';

is $tx->render(foo => { baz => { lang => 'Template' } }),
    'Hello, Template world!';

done_testing;
