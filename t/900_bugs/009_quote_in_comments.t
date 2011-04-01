#!perl -w
use strict;
use warnings;
use Test::More;

use Text::Xslate;

note 'Kolon';

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

note 'TTerse';

$tx = Text::Xslate->new(type => 'text', syntax => 'TTerse');

is $tx->render_string(<<'T'), "\n";
[% # it's a comment! %]
T

is $tx->render_string(<<'T'), "# it's a comment!\n";
[% "# it's a comment!" %]
T

is $tx->render_string(<<'T'), "# it's a comment!\n";
[% '# it\'s a comment!' %]
T

is $tx->render_string(<<'T'), "\n";
[% '' # it's a comment! %]
T

is $tx->render_string(<<'T'), "\n";
[%''# it's a comment! %]
T

is $tx->render_string(<<'T'), "Hello, world!\n";
[%# it's a comment!
    it is also a comment!
 -%]
Hello, world!
T

done_testing;

