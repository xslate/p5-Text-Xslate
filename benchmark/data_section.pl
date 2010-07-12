#!perl -w
use strict;

use Text::Xslate;
use Data::Section::Simple qw(get_data_section);

use FindBin qw($Bin);
use Benchmark qw(:all);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 10;

my $tx = Text::Xslate->new(
    path       => [ get_data_section(), "$Bin/template" ],
    cache_dir => "$Bin/template",
    cache     => 2,
);

my $vars = {
     books => [(
        { title => 'Islands in the stream' },
        { title => 'Beautiful code' },
        { title => 'Introduction to Psychology' },
        { title => 'Programming Perl' },
        { title => 'Compilers: Principles, Techniques, and Tools' },
     ) x $n],
};

{
    use Test::More;
    plan tests => 1;
    is $tx->render('list_ds.tx', $vars), $tx->render('list.tx', $vars)
        or die;
}

# suppose PSGI response body

cmpthese -1 => {
    file => sub {
        my $body = [$tx->render('list.tx', $vars)];
        return;
    },
    data => sub {
        my $body = [$tx->render('list_ds.tx', $vars)];
        return;
    },
};

__DATA__
@@ list_ds.tx
List:
: for $data ->($item) {
    * <:= $item.title :>
    * <:= $item.title :>
    * <:= $item.title :>
: }
