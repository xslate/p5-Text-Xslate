#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
);

my $tx = Text::Xslate->new(
    cache => 0,
    path => \%vpath,
    verbose => 2,
    warn_handler => sub { die @_ },
);

note 'for';
is $tx->render_string(<<'T'), <<'X' or die;
: for [42, 43, 44] -> $it {
    : last if $it == 43;
    * <:$it:>
: }
: else {
    nothing
: }
T
    * 42
X

is $tx->render_string(<<'T'), <<'X' or die;
: for [42, 43, 44] -> $it {
    : next if $it == 43;
    * <:$it:>
: }
: else {
    nothing
: }
T
    * 42
    * 44
X

note 'while';
my $iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
: while $iter() -> $it {
    : next if $it == 43;
    * <:$it:>
: }
T
    * 42
    * 44
X

$iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
: while $iter() -> $it {
    : last if $it == 43;
    * <:$it:>
: }
T
    * 42
X

$iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
: while $iter() -> $it {
    * <:$it:>
    : last if $it == 43;
: }
T
    * 42
    * 43
X

eval { $tx->render_string(': last') };
like $@, qr/Use of loop control statement \(last\)/;

eval { $tx->render_string(': next') };
like $@, qr/Use of loop control statement \(next\)/;

done_testing;
