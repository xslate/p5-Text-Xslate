#!perl -w
use strict;
use Test::More;
use Text::Xslate;
use Text::Xslate::Util qw(hash_with_default);

my $tx = Text::Xslate->new(
    cache => 0,
);

my $vars = hash_with_default {}, 'FILLME';

is $tx->render_string(<<'T', $vars), "Hello, FILLME world!\n";
Hello, <: $oops :> world!
T

is $tx->render_string(<<'T', $vars), "FILLME, FILLME, FILLME\n";
<: $a :>, <: $b :>, <: $c :>
T

$vars = hash_with_default {}, sub { "FILLME/@_" };

is $tx->render_string(<<'T', $vars), "Hello, FILLME/oops world!\n";
Hello, <: $oops :> world!
T

is $tx->render_string(<<'T', $vars), "FILLME/a, FILLME/b, FILLME/c\n";
<: $a :>, <: $b :>, <: $c :>
T

done_testing;

