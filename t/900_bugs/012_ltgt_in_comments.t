#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new();
local $TODO = 'not yet fixed';
ok eval {
    $tx->render_string(<<'T', { text => 'foo' });
<: $text :>!!
:# <a href="/">&gt;</a>
T
};
is $@, '';

done_testing;

