#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(cache => 0, path => [path]);

my $template = <<'T';
<:= $one :>
<:= $two :>
<:= $three :>
T

my $warn = '';
$SIG{__WARN__} = sub{ $warn .= join '', @_ };

eval {
    $tx->render_string($template, {one => 1, two => 2});
};
like $@, qr/^Xslate\Q(<input>:3/;

eval {
    $tx->render_string($template, {one => 1, three => 3});
};

like $@, qr/^Xslate\Q(<input>:2/;

eval {
    $tx->render_string($template, {two => 2, three => 3});
};

like $@, qr/^Xslate\Q(<input>:1/;

$template = <<'T';
<:= $one :>

<:= $three :>

<:= $five :>
T

eval {
    $tx->render_string($template, {one => 1, three => 3});
};
like $@, qr/^Xslate\Q(<input>:5/;

eval {
    $tx->render_string($template, {one => 1, five => 5});
};

like $@, qr/^Xslate\Q(<input>:3/;

eval {
    $tx->render_string(<<'T', {data => "foo"});

: for $data ->($item) {

* <:= $item :>

: }

T
};
like $@, qr/^Xslate\Q(<input>:2/;

{
    package Foo;
    sub bar { die 42 };
}

eval {
    $tx->render_string(<<'T', {foo => bless {}, 'Foo'});

<: $foo.bar :>

T
};

like $@, qr/^Xslate\Q(<input>:2/;

eval {
    $tx->render_string(<<'T', {});
: macro foo ->($bar) {
    <:= $bar :>
: }
: foo(nil);
T
};

like $@, qr/^Xslate\Q(<input>:2/, 'in a macro';

eval {
    $tx->render_string(<<'T', {});
    : macro foo ->($bar) {
        <:= $bar :>
    : }
    : macro foo ->($bar) {
        <:= $bar :>
    : }
T
};

like $@, qr/^Xslate::Compiler\Q(<input>:4/;
like $@, qr/Redefinition of macro/, 'macro redefinition';

eval {
    $tx->render_string(<<'T', {});
    : block foo ->($bar) {
        <:= $bar :>
    : }

    : block foo ->($bar) {
        <:= $bar :>
    : }
T
};

like $@, qr/^Xslate::Compiler\Q(<input>:5/;
like $@, qr/Redefinition of block/, 'block redefinition';

eval {
    $tx->render_string(<<'T', {});
    : cascade myapp::base

    : block hello ->($bar) {
        <:= $bar :>
    : }
T
};

like $@, qr/^Xslate::Compiler\Q(<input>:3/;
like $@, qr/Redefinition/, 'block redefinition';

eval {
    $tx->render_string(<<'T', {});
    : cascade myapp::bad_redefine
T
};

like $@, qr{^Xslate::Compiler\Q(myapp/bad_redefine.tx:3};
like $@, qr{\Qmyapp/base.tx};
like $@, qr/Redefinition/, 'block redefinition';

is $warn, '', "no warns";

done_testing;
