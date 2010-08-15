#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
    "base.tx" => <<'T',
: block main -> {}
T

    "derived.tx" => <<'T',
: cascade base
: around main -> {
    <: $o.foo :>
: }
T

    "block.tx" => <<'T',
: block main -> {
    <: $o.foo :>
: }
T

);

{
    package Foo;
    sub new { bless {} => shift }
    sub foo {
        die "foo";
    }
    package Bar;
    sub new { bless {} => shift }
    sub bar {
        eval { die "bar" };
    }
}

my $tx = Text::Xslate->new(path => \%vpath, cache => 0, verbose => 0);

ok $tx->render('block.tx', { o => Foo->new }), 'block';
ok $tx->render('block.tx', { o => Bar->new }), 'block';


ok $tx->render('derived.tx', { o => Foo->new }), 'cascade';
ok $tx->render('derived.tx', { o => Bar->new }), 'cascade';

is $tx->render_string('Hello, world!'), 'Hello, world!', 'render_string() works';

done_testing;
