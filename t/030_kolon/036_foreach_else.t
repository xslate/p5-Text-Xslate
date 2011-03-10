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

is $tx->render_string(<<'T'), <<'X';
: for [42] -> $it {
    * <:$it:>
: }
: else {
    nothing
: }
T
    * 42
X

is $tx->render_string(<<'T'), <<'X';
: for [] -> $it {
    * <:$it:>
: }
: else {
    nothing
: }
T
    nothing
X

is $tx->render_string(<<'T'), <<'X';
: for nil -> $it {
    * <:$it:>
: }
: else {
    nothing
: }
T
    nothing
X

done_testing;
