#!perl -w
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my %vpath = (
    'main.tx' => <<'T',
<: # it's a comment! :>
T
);

my $tx = Text::Xslate->new(path => \%vpath, cache => 0);
my $out = $tx->render('main.tx', { message => 'OK'});
is $out, "\n";

done_testing;

