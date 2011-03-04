#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my %vpath = (
    'foo.tx' => 'foo.tx',
);

my $tx = Text::Xslate->new(
    function => { f => sub { 'foo.tx' } },
    path  => \%vpath,
    cache => 0,
);

is eval { $tx->render_string(': include f() ') }, 'foo.tx';
is eval { $tx->render_string(': my $x = f(); include "" ~ $x;') }, 'foo.tx';
is eval { $tx->render_string(': my $x = f(); include $x; ') }, 'foo.tx';

done_testing;

