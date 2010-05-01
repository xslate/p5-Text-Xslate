#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

my $txc = Text::Xslate::Compiler->new(syntax => 'TTerse');

my $tx;

$tx = $txc->compile_str(<<'TX');
Hello, [% dialect %] world!
TX

is $tx->render({ dialect => 'TTerse' }), "Hello, TTerse world!\n", "Hello, world";

$tx = $txc->compile_str(<<'TX');
[% IF var == nil -%]
    $var is nil.
[% ELSIF var != "foo" -%]
    $var is not nil nor "foo".
[% ELSE -%]
    $var is "foo".
[% END -%]
TX

is $tx->render({ var => undef }),   "    \$var is nil.\n";
is $tx->render({ var => 0 }),     qq{    \$var is not nil nor "foo".\n};
is $tx->render({ var => "foo" }), qq{    \$var is "foo".\n};

$tx = $txc->compile_str(<<'TX');
[% IF var >= 1 && var <= 10 -%]
    $var is 1 .. 10
[% END -%]
TX

is $tx->render({ var =>  5 }), "    \$var is 1 .. 10\n";
is $tx->render({ var =>  0 }), "";
is $tx->render({ var => 11 }), "";

$tx = $txc->compile_str(<<'TX');
[% $var.value == nil ? "nil" : $var.value -%]
TX

is $tx->render({ var => {} }), "nil";
is $tx->render({ var => { value => "<foo>" }}), "&lt;foo&gt;";

$tx = $txc->compile_str(<<'TX');
[% FOREACH item IN data -%]
[[% item + 5 %]]
[% END -%]
TX

is $tx->render({ data => [1 .. 100] }),
    join('', map{ sprintf "[%d]\n", $_ + 5 } 1 .. 100);


done_testing;
