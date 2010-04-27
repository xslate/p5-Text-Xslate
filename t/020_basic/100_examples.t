#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $txc = Text::Xslate::Compiler->new();

my $tx = $txc->compile_str(<<'TX');
: if $var == nil {
    $var is nil.
: }
: else if $var != "foo" {
    $var is not nil nor "foo".
: }
: else {
    $var is "foo".
: }
TX

is $tx->render({ var => undef }),   "    \$var is nil.\n";
is $tx->render({ var => 0 }),     qq{    \$var is not nil nor "foo".\n};
is $tx->render({ var => "foo" }), qq{    \$var is "foo".\n};

$tx = $txc->compile_str(<<'TX');
: if( $var >= 1 && $var <= 10 ) {
    $var is 1 .. 10
: }
TX

is $tx->render({ var =>  5 }), "    \$var is 1 .. 10\n";
is $tx->render({ var =>  0 }), "";
is $tx->render({ var => 11 }), "";

$tx = $txc->compile_str(<<'TX');
:= $var.value == nil ? "nil" : $var.value
TX

is $tx->render({ var => {} }), "nil";
is $tx->render({ var => { value => "<foo>" }}), "&lt;foo&gt;";

$tx = $txc->compile_str(<<'TX');
: for $data ->($item) {
[<:= $item + 5 :>]
: } # end for
TX

is $tx->render({ data => [1 .. 100] }),
    join('', map{ sprintf "[%d]\n", $_ + 5 } 1 .. 100);


done_testing;
