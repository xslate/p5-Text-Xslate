#!perl -w
#
# global macros
#
use strict;
use Test::More skip_all => 'external macros are not yet implemented';

use Text::Xslate;

my %vpath = (
    'macro/common.tx' => <<'T',
: macro hello -> {
Hello, world!
: }
T

'foo.tx' => <<'T',
: import macro::common;
: hello()
T
);

my $tx = Text::Xslate->new(
    path => \%vpath,
);

is $tx->render('foo.tx'), "Hello, world!\n";

done_testing;

