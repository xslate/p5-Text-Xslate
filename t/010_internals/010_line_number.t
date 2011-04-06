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
like $warn, qr/\b Xslate \b/xms;
like $warn, qr/<string>:3/xms;
like $warn, qr/\b nil \b/xms;

$warn = '';
eval {
    $tx->render_string($template, {one => 1, three => 3});
};

like $warn, qr/\b Xslate \b/xms;
like $warn, qr/<string>:2/xms;
like $warn, qr/\b nil \b/xms;

$warn = '';
eval {
    $tx->render_string($template, {two => 2, three => 3});
};

like $warn, qr/\b Xslate \b/xms;
like $warn, qr/<string>:1/xms;
like $warn, qr/\b nil \b/xms;

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
like $warn, qr/<string>:5/xms;

$warn = '';
eval {
    $tx->render_string($template, {one => 1, five => 5});
};
is $@, '';
like $warn, qr/<string>:3/xms;

$warn = '';
eval {
    $tx->render_string(<<'T', {data => "foo"});

: for $data ->($item) {

* <:= $item :>

: }

T
};
is $@, '';
like $warn, qr/<string>:2/xms;

$warn = '';
eval {
    $tx->render_string(<<'T', {data => "foo"});

: if($data) {

* <:= $item :>

: }

T
};
is $@, '';
like $warn, qr/<string>:4/xms;

$warn = '';
eval {
    $tx->render_string(<<'T', {data => "foo"});

<:- if($data) { -:>

* <:= $item :>

<:- } -:>

T
};
is $@, '';
like $warn, qr/<string>:4/xms;


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
like $warn, qr/<string>:2/xms;
like $warn, qr/\b 42 \b/xms;

eval {
    $tx->render_string(<<'T', {});
: macro foo ->($bar) {
    <:= $bar :>
: }
: foo(nil);
T
};
is $@, '';
like $warn, qr/<string>:2/xms, 'in a macro';

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
like $@, qr/<string>:4/xms;
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
like $@, qr/<string>:5/xms;
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
like $@, qr/<string>:3/;
like $@, qr/Redefinition/, 'block redefinition';

$warn = '';
eval {
    $tx->render_string(<<'T', {});
    : cascade myapp::bad_redefine
T
};
is $warn, '';
like $@, qr{myapp.bad_redefine.tx:3}xms;
like $@, qr{myapp.base.tx};
like $@, qr/Redefinition/, 'block redefinition';

$warn = '';
eval {
    $tx->render("error/bad_include.tx", {});
};
is $warn, '';
like $@, qr/\b Xslate \b/xms, 'error/bad_include.tx';
like $@, qr{\b error.bad_include.tx:2 \b}xms;
like $@, qr{               'no_such_file' }xms;
like $@, qr{\b include \s+ "no_such_file" }xms;

$warn = '';
eval {
    $tx->render("error/bad_syntax.tx", {});
};
is $warn, '';
like $@, qr/\b Xslate \b/xms, 'error/bad_syntax.tx';
like $@, qr{\b error.bad_syntax.tx:4 \b}xms;
like $@, qr/\b dump \b/xms;

$warn = '';
eval {
    $tx->render("error/bad_tags.tx", {});
};
is $warn, '';
like $@, qr/\b Xslate \b/xms, 'error/bad_tags.tx';
like $@, qr{\b error.bad_tags.tx:7 \b}xms;
like $@, qr/\b Malformed \b/xms;

$warn = '';
eval {
    $tx->render("error/bad_method.tx", {});
};
is $@, '';
like $warn, qr/\b Xslate \b/xms, 'error/bad_method.tx';
like $warn, qr{\b error.bad_method.tx:5 \b}xms;
like $warn, qr{\b foobar \b}xms;

# __FILE__ and __LINE__ with TTerse
$tx = Text::Xslate->new(syntax => 'TTerse');
is $tx->render_string(<<'T'), <<'X', '__FILE__';
    [% __FILE__ %]
T
    &lt;string&gt;
X

is $tx->render_string(<<'T'), <<'X', '__LINE__';
    .
    .
    [% __LINE__ %]
    .
    .
T
    .
    .
    3
    .
    .
X

is $tx->render_string(<<'T'), <<'X', '__LINE__ with prechomp/postchomp';
[% __LINE__ %]
[% IF 1 -%]
    [% __LINE__ %]
[% END -%]
[% __LINE__ %]
T
1
    3
5
X

is $tx->render_string(<<'T'), '123', '__LINE__ with prechomp/postchomp';
[%- __LINE__ -%]
[%- __LINE__ -%]
[%- __LINE__ -%]
T

is $tx->render_string(<<'T'), '135', '__LINE__ with prechomp/postchomp';
[%- __LINE__ -%]

[%- __LINE__ -%]

[%- __LINE__ -%]
T

done_testing;
