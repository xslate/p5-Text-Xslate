#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $warn;

my $tx = Text::Xslate->new(
    verbose => 2,
    warn_handler => sub{ $warn .= join '', @_ },
    cache => 0,
    path => [path]);

my $template = <<'T';
<:= $one :>
<:= $two :>
<:= $three :>
T

$warn = '';
eval {
    $tx->render_string($template, {one => 1, two => 2});
};
like $warn, qr/^Xslate\Q(<input>:3/;

$warn = '';
eval {
    $tx->render_string($template, {one => 1, three => 3});
};

like $warn, qr/^Xslate\Q(<input>:2/;

$warn = '';
eval {
    $tx->render_string($template, {two => 2, three => 3});
};

like $warn, qr/^Xslate\Q(<input>:1/;

$template = <<'T';
<:= $one :>

<:= $three :>

<:= $five :>
T

$warn = '';
eval {
    $tx->render_string($template, {one => 1, three => 3});
};
is $@, '';
like $warn, qr/^Xslate\Q(<input>:5/;

$warn = '';
eval {
    $tx->render_string($template, {one => 1, five => 5});
};
is $@, '';
like $warn, qr/^Xslate\Q(<input>:3/;

$warn = '';
eval {
    $tx->render_string(<<'T', {data => "foo"});

: for $data ->($item) {

* <:= $item :>

: }

T
};
is $@, '';
like $warn, qr/^Xslate\Q(<input>:2/;

{
    package Foo;
    sub bar { die 42 };
}

$warn = '';
eval {
    $tx->render_string(<<'T', {foo => bless {}, 'Foo'});

<: $foo.bar :>

T
};
is $@, '';
like $warn, qr/^Xslate\Q(<input>:2/;

eval {
    $tx->render_string(<<'T', {});
: macro foo ->($bar) {
    <:= $bar :>
: }
: foo(nil);
T
};
is $@, '';
like $warn, qr/^Xslate\Q(<input>:2/, 'in a macro';

$warn = '';
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
is $warn, '';
like $@, qr/^Xslate::Compiler\Q(<input>:4/;
like $@, qr/Redefinition of macro/, 'macro redefinition';

$warn = '';
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
is $warn, '';
like $@, qr/^Xslate::Compiler\Q(<input>:5/;
like $@, qr/Redefinition of block/, 'block redefinition';

$warn = '';
eval {
    $tx->render_string(<<'T', {});
    : cascade myapp::base

    : block hello ->($bar) {
        <:= $bar :>
    : }
T
};

is $warn, '';
like $@, qr/^Xslate::Compiler\Q(<input>:3/;
like $@, qr/Redefinition/, 'block redefinition';

$warn = '';
eval {
    $tx->render_string(<<'T', {});
    : cascade myapp::bad_redefine
T
};
is $warn, '';
like $@, qr{^Xslate::Compiler\Q(myapp/bad_redefine.tx:3};
like $@, qr{\Qmyapp/base.tx};
like $@, qr/Redefinition/, 'block redefinition';


done_testing;
