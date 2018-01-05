use strict;
use warnings;

use Test::Requires qw(Data::Section::Simple);
use Text::Xslate;
use Text::Xslate::Util;
use Test::More;

my $vpath = Data::Section::Simple->new()->get_data_section();
my $vars = { foo => 'hoge', bar => 'fuga' };

my $xslate = Text::Xslate->new(path => [$vpath], cache => 0);

my $tied = Text::Xslate::Util::hash_with_default($vars, sub { "FILL @_" });
my $got = $xslate->render('base.tx', $tied);
is($got, "foo:hoge, bar:fuga\n", "localize tied hash");

done_testing;

__DATA__
@@ base.tx
:include _partial { foo => $foo }
@@ _partial.tx
foo:<: $foo :>, bar:<: $bar :>
