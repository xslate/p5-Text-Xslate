#!perl -w
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(type => 'text');

is $tx->render_string(<<'T'), "\n";
<: # it's a comment! :>
T

is $tx->render_string(<<'T'), "# it's a comment!\n";
<: "# it's a comment!" :>
T

is $tx->render_string(<<'T'), "# it's a comment!\n";
<: '# it\'s a comment!' :>
T

is $tx->render_string(<<'T'), "\n";
<: '' # it's a comment! :>
T

is $tx->render_string(<<'T'), "\n";
<:''# it's a comment! :>
T

done_testing;

