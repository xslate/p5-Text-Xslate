#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tt = Text::Xslate->new(
    syntax => 'TTerse',
    cache  => 0,
);

is $tt->render_string(<<'T'), "- 42\n";
%% foreach x in [42]
- [% x %]
%% end
T

is $tt->render_string(<<'T'), "- 42\n";
%% foreach in in [42]
- [% in %]
%% end
T

done_testing;

