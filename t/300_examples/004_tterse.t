#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'TTerse');

my $tmpl;

$tmpl = <<'TX';
Hello, [% dialect %] world!
TX

is $tx->render_string($tmpl, { dialect => 'Kolon' }), "Hello, Kolon world!\n", "Hello, world";

$tmpl = <<'TX';
[% IF var == nil -%]
    $var is nil.
[% ELSIF var != "foo" -%]
    $var is not nil nor "foo".
[% ELSE -%]
    $var is "foo".
[% END -%]
TX

is $tx->render_string($tmpl, { var => undef }),   "    \$var is nil.\n";
is $tx->render_string($tmpl, { var => 0 }),     qq{    \$var is not nil nor "foo".\n};
is $tx->render_string($tmpl, { var => "foo" }), qq{    \$var is "foo".\n};

$tmpl = <<'TX';
[% IF var >= 1 && var <= 10 -%]
    $var is 1 .. 10
[% END -%]
TX

is $tx->render_string($tmpl, { var =>  5 }), "    \$var is 1 .. 10\n";
is $tx->render_string($tmpl, { var =>  0 }), "";
is $tx->render_string($tmpl, { var => 11 }), "";

$tmpl = <<'TX';
[% var.value == nil ? "nil" : var.value -%]
TX

is $tx->render_string($tmpl, { var => {} }), "nil";
is $tx->render_string($tmpl, { var => { value => "<foo>" }}), "&lt;foo&gt;";

$tmpl = <<'TX';
[% FOREACH item IN data -%]
[[% item + 5 %]]
[% END -%]
TX

is $tx->render_string($tmpl, { data => [1 .. 100] }),
    join('', map{ sprintf "[%d]\n", $_ + 5 } 1 .. 100);


done_testing;
