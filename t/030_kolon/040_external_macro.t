#!perl -w
#
# global macros
#
use strict;
use Test::More skip_all => 'TODO';

use Text::Xslate;

my %vpath = (
    'macro/bar.tx' => <<'T',
: our macro hello -> {
Hello, world!
: end
T

'foo.tx' => <<'T',
: include macro::bar;
: macro::bar::hello()
T
);

my $tx = Text::Xslate->new( path => \%vpath );

is $tx->render('foo.tx'), "Hello, world!\n";

done_testing;

