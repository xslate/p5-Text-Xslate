#!perl
# For poor environment, e.g. CGI applications without XS
BEGIN { $ENV{PERL_ONLY}= 1 }
use strict;
use warnings;

use Getopt::Long;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

use Template;
use HTML::Template;
use Text::MicroTemplate::Extended;

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

GetOptions(
    'booster'    => \my $pp_booster,
    'opcode'     => \my $pp_opcode,

    'size=i'     => \my $n,
    'template=s' => \my $tmpl,
    'help'       => \my $help,
);

die <<'HELP' if $help;
perl -Mblib benchmark/x-poor-env.pl [--size N] [--template NAME] [--opcode|booster]

This is a general benchmark utility for poor environment,
assuming CGI applications using only pure Perl modules.
See also benchmark/x-rich-env.pl.
HELP

$tmpl = 'include' if not defined $tmpl;
$n    = 100       if not defined $n;

if(defined $pp_booster) {
    $ENV{XSLATE} = 'pp=booster';
}
elsif(defined $pp_opcode) {
    $ENV{XSLATE} = 'pp=opcode';
}

$ENV{MOUSE_PUREPERL} = 1;
$Template::Config::STASH = 'Template::Stash'; # Instead of Stash::XS

require Text::Xslate::PP;

foreach my $mod(qw(
    Text::Xslate
    Template
    HTML::Template
    Text::MicroTemplate
    Text::MicroTemplate::Extended
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $path = "$Bin/template";

my $vars = {
    data => [ ({
            title    => "<FOO>",
            author   => "BAR",
            abstract => "BAZ",
        }) x $n
   ],
};

TEST: {
    my $tx = Text::Xslate->new(
        path       => [$path],
        cache_dir  =>  '.xslate_cache',
        cache      => 2,
    );
    my $mt = Text::MicroTemplate::Extended->new(
        include_path => [$path],
        use_cache    => 2,
    );
    my $tt = Template->new(
        INCLUDE_PATH => [$path],
        COMPILE_EXT  => '.out',
    );

    my $ht = HTML::Template->new(
        path              => [$path],
        filename          => "$tmpl.ht",
        case_sensitive    => 1,
        die_on_bad_params => 0,
        double_file_cache => 1,
        file_cache_dir    => '.xslate_cache',
    );

    my $expected = $tx->render("$tmpl.tx", $vars);
    $expected =~ s/\n+/\n/g;


    plan tests => 3;

    $tt->process("$tmpl.tt", $vars, \my $out) or die $tt->error;
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TT: Template-Toolkit';

    $out = $mt->render_file($tmpl, $vars);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'MT: Text::MicroTemplate';

    $ht->param($vars);
    $out = $ht->output();
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'HT: HTML::Template';
}

print "Benchmarks with '$tmpl' (datasize=$n)\n";
cmpthese -1 => {
    Xslate => sub {
        my $tx = Text::Xslate->new(
            path       => [$path],
            cache_dir  =>  '.xslate_cache',
            cache      => 2,
        );
        my $body = $tx->render("$tmpl.tx", $vars);
        return;
    },
    MT => sub {
        my $mt = Text::MicroTemplate::Extended->new(
            include_path => [$path],
            cache        => 2,
        );
        my $body = $mt->render_file($tmpl, $vars);
        return;
    },
    TT => sub {
        my $tt = Template->new(
            INCLUDE_PATH => [$path],
            COMPILE_EXT  => '.out',
        );
        my $body;
        $tt->process("$tmpl.tt", $vars, \$body) or die $tt->error;
        return;
    },
    HT => sub {
        my $ht = HTML::Template->new(
            path              => [$path],
            filename          => "$tmpl.ht",
            case_sensitive    => 1,
            die_on_bad_params => 0,
            double_file_cache => 1,
            file_cache_dir    => '.xslate_cache',
        );

        $ht->param($vars);
        my $body = $ht->output();
        return;
    },
};

