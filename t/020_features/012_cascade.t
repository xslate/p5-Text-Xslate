#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

note 'cascade without components';
my $tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade myapp::base
T

is $tx->render({lang => 'Xslate'}), <<'T', "template cascading" for 1 .. 2;
HEAD
    Hello, Xslate world!
FOOT
T

$tx = Text::Xslate->new(string => <<'T', cache => 0, path => [path]);
: cascade "myapp/base.tx"
T

is $tx->render({lang => 'Xslate'}), <<'T', "with filename" for 1 .. 2;
HEAD
    Hello, Xslate world!
FOOT
T

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

is $tx->render({lang => 'Xslate'}), <<'T' for 1 .. 2;
HEAD
    BEFORE
    Hello, Xslate world!
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

is $tx->render({lang => 'Xslate'}), <<'T' for 1 .. 2;
HEAD
    BEFORE
    D-BEFORE
    Hello, Xslate world!
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

is $tx->render({lang => 'Xslate'}), <<'T' for 1 .. 2;
HEAD
    BEFORE
    AROUND[
    Hello, Xslate world!
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

is $tx->render({lang => 'Xslate'}), <<'T' for 1 .. 2;
HEAD
    BEFORE
    AROUND[
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
    ]AROUND
    AFTER
FOOT
T

note "file";
is $tx->render('myapp/derived.tx', {lang => 'Xslate'}), <<'T', "file ($_)" for 1 .. 2;
HEAD
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
FOOT
T

$tx = Text::Xslate->new(path => [path]);
is $tx->render('myapp/derived.tx', {lang => 'Xslate'}), <<'T', "file again ($_)" for 1 .. 2;
HEAD
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
FOOT
T

done_testing;
