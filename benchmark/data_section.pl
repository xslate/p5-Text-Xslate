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

my $tx1 = Text::Xslate->new(
    path       => [ get_data_section(), "$Bin/template" ],
    cache_dir => ".xslate_cache",
    cache     => 1,
);

my $tx2 = Text::Xslate->new(
    path       => [ get_data_section(), "$Bin/template" ],
    cache_dir => ".xslate_cache",
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
    plan tests => 2;
    is $tx1->render('list_ds.tx', $vars), $tx1->render('list.tx', $vars)
        or die;
    is $tx2->render('list_ds.tx', $vars), $tx2->render('list.tx', $vars)
        or die;
}

print "Files v.s. __DATA__ with cache => 1 or 2\n";
cmpthese -1 => {
    'file/1' => sub {
        my $body = [$tx1->render('list.tx', $vars)];
        return;
    },
    'file/2' => sub {
        my $body = [$tx2->render('list.tx', $vars)];
        return;
    },
    'vpath/1' => sub {
        my $body = [$tx1->render('list_ds.tx', $vars)];
        return;
    },
    'vpath/2' => sub {
        my $body = [$tx2->render('list_ds.tx', $vars)];
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
