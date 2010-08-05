#!perl
# templates: benchmark/template/list.*

use strict;
use warnings;

use Text::MicroTemplate::Extended;
use Template;
use Getopt::Long;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

GetOptions(
    'mst' => \my $try_mst,
    'pp'  => \my $pp,
    'booster' => \my $pp_booster,
);


if ($pp) {
    print "testing with PP\n";
    $Template::Config::STASH = 'Template::Stash';
    $ENV{XSLATE} = $pp_booster ? 'pp=booster' : 'pp';
    $ENV{MOUSE_PUREPERL} = 1;
}

require Text::Xslate;

my $tmpl   = !Scalar::Util::looks_like_number($ARGV[0]) && shift(@ARGV);
   $tmpl ||= 'list';
my $n      = shift(@ARGV) || 100;

if(!($tmpl eq 'list' or $tmpl eq 'include')) {
    die "$0 [list | include] [n]\n";
}

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

my $has_tcs = eval q{ use Text::ClearSilver 0.10.5.4; 1 };
warn "Text::ClearSilver is not available ($@)\n" if $@;

my $has_mst = ($tmpl eq 'list' && $try_mst && eval q{ use MobaSiF::Template; 1 });
warn "MobaSiF::Template is not available ($@)\n" if $try_mst && $@;

my $has_htp = eval q{ use HTML::Template::Pro; 1 };
warn "HTML::Template::Pro is not available ($@)\n" if $@;

my $has_ht = eval q{ use HTML::Template; 1 };
warn "HTML::Template is not available ($@)\n" if $@;

foreach my $mod(qw(
    Text::Xslate Text::MicroTemplate Template
    Text::ClearSilver MobaSiF::Template HTML::Template::Pro
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  '.xslate_cache',
    cache      => 2,
);
my $mt = Text::MicroTemplate::Extended->new(
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

my $htp;
if($has_htp) {
    $htp = HTML::Template::Pro->new(
        path           => [$path],
        filename       => "$tmpl.ht",
        case_sensitive => 1,
    );
}

my $ht;
if($has_ht) {
    $ht = HTML::Template->new(
        path           => [$path],
        filename       => "$tmpl.ht",
        case_sensitive => 1,
        die_on_bad_params => 0,
    );
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
    $tests++ if $has_htp;
    $tests++ if $has_ht;
    plan tests => $tests;

    $tt->process("$tmpl.tt", $vars, \my $out) or die $tt->error;
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TT: Template-Toolkit';

    $out = $mt->render_file($tmpl, $vars);
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

    if($has_htp) {
        $htp->param($vars);
        $out = $htp->output();
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'HTP: HTML::Template::Pro';
    }

    if($has_ht) {
        $ht->param($vars);
        $out = $ht->output();
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'HT: HTML::Template';
    }
}

print "Benchmarks with '$tmpl' (datasize=$n)\n";
cmpthese -1 => {
    Xslate => sub {
        my $body = $tx->render("$tmpl.tx", $vars);
        return;
    },
    MT => sub {
        my $body = $mt->render_file($tmpl, $vars);
        return;
    },
    TT => sub {
        my $body;
        $tt->process("$tmpl.tt", $vars, \$body) or die $tt->error;
        return;
    },

    (!$pp && $has_tcs) ? (
        TCS => sub {
            my $body;
            $tcs->process("$tmpl.cs", $vars, \$body);
            return;
        },
    ) : (),
    (!$pp && $has_mst) ? (
        MST => sub {
            my $body = MobaSiF::Template::insert($mst_bin, $vars);
            return;
        },
    ) : (),
    (!$pp && $has_htp) ? (
        HTP => sub {
            $htp->param($vars);
            my $body = $htp->output();
            return;
        },
    ) : (),
    $has_ht ? (
        HT => sub {
            $ht->param($vars);
            my $body = $ht->output();
            return;
        },
    ) : (),
};

