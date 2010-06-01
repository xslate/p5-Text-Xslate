#!perl

# templates: benchmark/template/list.*

use strict;
use warnings;

use Text::Xslate;
use Text::MicroTemplate::File;
use Template;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

my $has_tcs = eval q{ use Text::ClearSilver 0.10.5.4; 1 };
warn "Text::CelarSilver is not available ($@)\n";

my $has_mst = eval q{ use MobaSiF::Template; 1 };
warn "MobaSif::Template is not available ($@)\n";

foreach my $mod(qw(
    Text::Xslate Text::MicroTemplate Template
    Text::ClearSilver MobaSiF::Template
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $n    = shift(@ARGV) || 100;
my $tmpl = 'list';

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  $path,
    cache      => 2,
);
my $mt = Text::MicroTemplate::File->new(
    include_path => [$path],
    cache        => 2,
);
my $tt = Template->new(
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.out',
);

my $tcs;
if($has_tcs) {
    $tcs = Text::ClearSilver->new(
        VarEscapeMode => 'html',
        load_path     => [$path],
    );
}

my $mst_in  = "$Bin/template/list.mst";
my $mst_bin = "$Bin/template/list.mst.out";
if($has_mst) {
    MobaSiF::Template::Compiler::compile($mst_in, $mst_bin);
}

my $vars = {
    data => [ ({
            title    => "FOO",
            author   => "BAR",
            abstract => "BAZ",
        }) x $n
   ],
};

{
    my $expected = $tx->render("$tmpl.tx", $vars);
    $expected =~ s/\n+/\n/g;

    my $tests = 2;
    $tests++ if $has_tcs;
    $tests++ if $has_mst;
    plan tests => $tests;

    $tt->process("$tmpl.tt", $vars, \my $out) or die $tt->error;
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TT: Template-Toolkit';

    $out = $mt->render_file("$tmpl.mt", $vars);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'MT: Text::MicroTemplate';

    if($has_tcs) {
        $tcs->process("$tmpl.cs", $vars, \$out);
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'TCS: Text::ClearSilver';
    }

    if($has_mst) {
        $out = MobaSiF::Template::insert($mst_bin, $vars);
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'MST: MobaSiF::Template';
    }
}

cmpthese -1 => {
    Xslate => sub {
        my $body = $tx->render("$tmpl.tx", $vars);
        return;
    },
    MT => sub {
        my $body = $mt->render_file("$tmpl.mt", $vars);
        return;
    },
    TT => sub{ 
        my $body;
        $tt->process("$tmpl.tt", $vars, \$body) or die $tt->error;
        return;
    },

    $has_tcs ? (
        TCS => sub{
            my $body;
            $tcs->process("$tmpl.cs", $vars, \$body);
            return;
        },
    ) : (),
    $has_mst ? (
        MST => sub{
            my $body = MobaSiF::Template::insert($mst_bin, $vars);
            return;
        },
    ) : (),
};

