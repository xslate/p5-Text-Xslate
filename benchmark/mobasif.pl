#!perl
use strict;
use Benchmark qw(:all);
use Config; printf "Perl/%vd on %s\n", $^V, $Config{archname};

use Text::Xslate;
use MobaSiF::Template;

foreach my $mod(qw(Text::Xslate MobaSiF::Template)) {
    print $mod, "/", $mod->VERSION, "\n";
}

my $vars      = {
    hoge => 1,
    fuga => "fuga",
};
my @load_path = qw(benchmark/template);

my $mst_in  = "benchmark/template/simple.mst";
my $mst_bin = "benchmark/template/simple.mst.out";
MobaSiF::Template::Compiler::compile($mst_in, $mst_bin);

my $tx = Text::Xslate->new(file => 'simple.tx', path => \@load_path);

$tx->render($vars) eq MobaSiF::Template::insert($mst_bin, $vars)
    or MobaSiF::Template::insert($mst_bin, $vars);

cmpthese -1, {
    'Xslate' => sub {
        my $output = $tx->render('simple.tx', $vars);
        return;
    },
    'MobaSiF::T' => sub {
        my $output = MobaSiF::Template::insert($mst_bin, $vars);
        return;
    },
};
