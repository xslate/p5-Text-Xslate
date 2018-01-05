#!perl
# issues/45: nested macro modifiers
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);

use Text::Xslate;

my %vpath = (
    X => <<'T',
: block sugyan -> {
This is X.
: }
T

    Y => <<'T',
: cascade "X"
: around sugyan -> {
This is Y.
: }
T
    Z => <<'T',
: cascade "Y"
: around sugyan -> {
This is Z.
: }
T
);

my $xslate = Text::Xslate->new(
    path => [\%vpath],
    cache_dir => tempdir(CLEANUP => 1),
);
is eval { $xslate->render('Z') }, "This is Z.\n";
is $@, '';
done_testing;
