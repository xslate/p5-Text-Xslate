#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Fatal qw(open);

use t::lib::Util;

my $err = '';
my $tx = Text::Xslate->new(string => <<'T', error_handler => sub{ $err = "@_" });
Hello, <:= $lang :> world!
T

is $tx->render({ lang => undef }), "Hello,  world!\n", "error handler" for 1 .. 2;

like $err, qr/Use of uninitialized value/, 'warnings are ignored';

done_testing;
