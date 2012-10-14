#!perl
# recursive call of render()
# related to issue #65 but there are no problems.
#
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my %vpath = (
    foo => <<'T',
: for [42] -> $i {
    : render('bar');
: }
T

    bar => <<'T',
Hello, world!
T
);

my $tx;
$tx = Text::Xslate->new(
    cache => 0,
    path  => [\%vpath],

    function => {
        render => sub {
            return $tx->render(@_);
        },
    },
);

is $tx->render('foo'), "Hello, world!\n";

done_testing;

