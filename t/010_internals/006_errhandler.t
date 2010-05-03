#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $err = '';
my $tx = Text::Xslate->new( error_handler => sub{ $err = "@_" });

is $tx->render_string(
    'Hello, <:= $lang :> world!',
    { lang => undef }), "Hello,  world!", "error handler" for 1 .. 2;

like $err, qr/Use of uninitialized value/, 'warnings are produced';

# TODO more tests

done_testing;
