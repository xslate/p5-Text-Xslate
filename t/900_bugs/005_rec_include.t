#!perl -w
# copied from t/030_kolon/009_include.t
use strict;
#use warnings FATAL => 'all';

use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new( cache => 0, path => [path] );

eval {
    $tx->render('include2.tx', { file => 'include2.tx', lang => 'Xslate' });
};

like $@, qr/too deep/, 'first';
note $@;

eval {
    $tx->render('include2.tx', { file => 'include2.tx', lang => 'Xslate' });
};

like $@, qr/too deep/, 'second';
note $@;

done_testing;

