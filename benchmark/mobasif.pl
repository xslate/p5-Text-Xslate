#!perl
use strict;

use Text::Xslate;
use MobaSiF::Template;

use FindBin qw($Bin);
use Benchmark qw(:all);

use Test::More;

use Config; printf "Perl/%vd on %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate MobaSiF::Template)) {
    print $mod, "/", $mod->VERSION, "\n";
}

my $vars      = {
    hoge => 1,
    fuga => "fuga",
};

my $mst_in  = "$Bin/template/simple.mst";
my $mst_bin = "$Bin/template/simple.mst.out";
MobaSiF::Template::Compiler::compile($mst_in, $mst_bin);

my $tx = Text::Xslate->new(
    path      => ["$Bin/template"],
    cache_dir => "$Bin/template",
    cache     => 2,
);

{
    plan tests => 1;
    is MobaSiF::Template::insert($mst_bin, $vars), $tx->render('simple.tx', $vars), 'MST';
}

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
