#!perl -w
use strict;
use warnings;

use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'TTerse');

is $tx->render_string(<<'T'), <<'X';
%% for i in [42]
{[% i %]}
%% else
empty
%% end
T
{42}
X

is $tx->render_string(<<'T'), <<'X';
%% for i in []
{[% i %]}
%% else
empty
%% end
T
empty
X

is $tx->render_string(<<'T', { y => 'y' }), <<'X';
%% FOR i IN []
{[% i %]}
%% ELSE
empt[% $y %]
%% END
T
empty
X

done_testing;

