#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/107
use strict;
use warnings;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(hash_with_default);


my $tx = Text::Xslate->new();
is($tx->render_string('[<: $oops :>]', hash_with_default(+{}, sub { 'null' })), '[null]');
is($tx->render_string('[<: $oops :>]', hash_with_default(+{ oops => undef }, sub { 'null' })), '[]');

done_testing;
