#!perl -w
use strict;
use Benchmark qw(:all);

use Text::Xslate;

my $tx = Text::Xslate->new();
my $tt = Text::Xslate->new(syntax => 'TTerse');

my $x = <<'T';
List:
: for $data ->($item) {
    * <:= $item.title :>
    * <:= $item.title :>
    * <:= $item.title :>
: }
T

my $y = <<'T';
List:
[% FOREACH item IN data -%]
    * [% item.title %]
    * [% item.title %]
    * [% item.title %]
[% END -%]
T

print "Parser: Kolon v.s. TTerse\n";
cmpthese 0, {
    kolon  => sub { $tx->compile($x) },
    tterse => sub { $tt->compile($y) },
};
