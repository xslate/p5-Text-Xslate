#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

note 'cascade without components';
my $tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::base
T

is $tx->render({}), "HEAD\n    Hello, world!\nFOOT\n", 'template cascading';
is $tx->render({}), "HEAD\n    Hello, world!\nFOOT\n", 'template cascading';

note 'cascade one-level';
$tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::base

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T

is $tx->render({}), <<'T', "before & after" for 1 .. 2;
HEAD
    BEFORE
    Hello, world!
    AFTER
FOOT
T

note 'cascade two-level';
$tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::derived

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T

is $tx->render({}), <<'T', "before & after" for 1 .. 2;
HEAD
    BEFORE
    D-BEFORE
    Hello, world!
    D-AFTER
    AFTER
FOOT
T

note 'cascade one-level with around';
$tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::base

: around hello -> {
    AROUND[
    : super
    ]AROUND
: }

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T

is $tx->render({}), <<'T', "before & after" for 1 .. 2;
HEAD
    BEFORE
    AROUND[
    Hello, world!
    ]AROUND
    AFTER
FOOT
T

note 'cascade two-level with around';
$tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::derived

: around hello -> {
    AROUND[
    : super
    ]AROUND
: }

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T

is $tx->render({}), <<'T', "before & after" for 1 .. 2;
HEAD
    BEFORE
    AROUND[
    D-BEFORE
    Hello, world!
    D-AFTER
    ]AROUND
    AFTER
FOOT
T

done_testing;
