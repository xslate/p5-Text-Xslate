#!perl -w
# "Strings with code points over 0xFF may not be mapped into in-memory file handles"
use strict;
use warnings;
use utf8;
use Test::More;

use Text::Xslate;

my %vpath = (
    entry => 'あいう'
);

my $tx = Text::Xslate->new( cache => 0, path => \%vpath );
is $tx->render('entry'), 'あいう';

done_testing;

