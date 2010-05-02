#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(
    string => <<'TX',
<:= $one :>
<:= $two :>
<:= $three :>
TX
);

my $warn = '';
$SIG{__WARN__} = sub{ $warn .= join '', @_ };

eval {
    $tx->render({one => 1, two => 2});
};
like $@, qr/^Xslate\Q(<input>:3/;

eval {
    $tx->render({one => 1, three => 3});
};

like $@, qr/^Xslate\Q(<input>:2/;

eval {
    $tx->render({two => 2, three => 3});
};

like $@, qr/^Xslate\Q(<input>:1/;

$tx = Text::Xslate->new(
    string => <<'TX',
<:= $one :>

<:= $three :>

<:= $five :>
TX
);

eval {
    $tx->render({one => 1, three => 3});
};
like $@, qr/^Xslate\Q(<input>:5/;

eval {
    $tx->render({one => 1, five => 5});
};

like $@, qr/^Xslate\Q(<input>:3/;

$tx = Text::Xslate->new(
    string => <<'TX',

: for $data ->($item) {

* <:= $item :>

: }

TX
);

eval {
    $tx->render({data => "foo"});
};
like $@, qr/^Xslate\Q(<input>:2/;

{
    package Foo;
    sub bar { die 42 };
}

$tx = Text::Xslate->new(
    string => "\n<:= \$foo.bar :>",
);

eval {
    $tx->render({foo => bless {}, 'Foo'});
};

like $@, qr/^Xslate\Q(<input>:2/;

$tx = Text::Xslate->new(
    string => <<'T',
: macro foo ->($bar) {
    <:= $bar :>
: }
: foo(nil);
T
);

eval {
    $tx->render({});
};

like $@, qr/^Xslate\Q(<input>:2/, 'in a macro';

eval {
    $tx = Text::Xslate->new(
        string => <<'T',
    : macro foo ->($bar) {
        <:= $bar :>
    : }
    : macro foo ->($bar) {
        <:= $bar :>
    : }
T
    );

    $tx->render({});
};

like $@, qr/^Xslate::Compiler\Q(<input>:4/;
like $@, qr/Redefinition of macro/, 'macro redefinition';

eval {
    $tx = Text::Xslate->new(
        string => <<'T',
    : block foo ->($bar) {
        <:= $bar :>
    : }

    : block foo ->($bar) {
        <:= $bar :>
    : }
T
    );

    $tx->render({});
};

like $@, qr/^Xslate::Compiler\Q(<input>:5/;
like $@, qr/Redefinition of block/, 'block redefinition';

eval {
    $tx = Text::Xslate->new(
        cache  => 0,
        path   => [path],
        string => <<'T',
    : cascade myapp::base

    : block hello ->($bar) {
        <:= $bar :>
    : }
T
    );

    $tx->render({});
};

like $@, qr/^Xslate::Compiler\Q(<input>:3/;
like $@, qr/Redefinition/, 'block redefinition';

is $warn, '', "no warns";

done_testing;
