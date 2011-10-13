#!perl -w
#
# external macros
#
use strict;
use Test::More skip_all => 'TODO';

use Text::Xslate;

my %vpath = (
    'foo.tx' => <<'T',
: macro::bar::hello()
T
    'macro/bar.tx' => <<'T',
: macro bar -> {
Hello, world!
: end
T

);

my $tx = Text::Xslate->new( path => \%vpath );

is $tx->render('foo.tx'), "Hello, world!\n";

done_testing;

