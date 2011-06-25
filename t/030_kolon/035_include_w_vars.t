#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
    foo => ': include "bar" { $baz }',
    bar => 'Hello, <: $lang :> world!',
);

my $tx = Text::Xslate->new(
    cache => 0,
    path => \%vpath,
    verbose => 2,
    warn_handler => sub { die @_ },
);

is $tx->render(foo => { baz => { lang => 'Xslate' } }),
    'Hello, Xslate world!';

is $tx->render(foo => { baz => { lang => 'Template' } }),
    'Hello, Template world!';

is $tx->render_string(':include "bar" { $baz }; $lang',
    { baz => { lang => 'Xslate' }, lang => '!!' }),
    'Hello, Xslate world!!!';

is $tx->render_string(':include "bar" { $baz.merge({ lang => "Xslate"}) }; $lang',
    { baz => {  }, lang => '!!' }),
    'Hello, Xslate world!!!';

eval { $tx->render_string(': include "bar" { a => 42, "b" }' ) };
like $@, qr/pairs/;

eval { $tx->render_string(': include "bar" { 42 }' ) };
like $@, qr/must be a HASH reference/;

eval { $tx->render('foo', { baz => { }, lang => 'XXX'} ) };
like $@, qr/nil/;

done_testing;
