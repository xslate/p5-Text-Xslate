#!perl -w
use strict;
use warnings;
use Test::More;

use Text::Xslate;

use Tie::Hash;

tie my %vars, 'Tie::StdHash';
%vars = (
    bar => 'Hello',
);
my $tx = Text::Xslate->new(cache => 0);
my $out = $tx->render_string(
    '<: $foo.bar ~ ", world!" :>',
    { foo => \%vars });
is $out, "Hello, world!";
done_testing;
