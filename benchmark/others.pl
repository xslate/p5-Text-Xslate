#!perl -w

# templates: benchmark/template/list.*

use 5.010;
use strict;

use Text::Xslate;
use Text::ClearSilver 0.10.5.4;
use Text::MicroTemplate::File;
use Template;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate Text::ClearSilver Template)){
    say $mod, '/', $mod->VERSION;
}

my $n    = shift(@ARGV) || 100;
my $tmpl = 'list';

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  $path,
    cache      => 2,
);
my $tcs = Text::ClearSilver->new(
    VarEscapeMode => 'html',
    load_path     => [$path],
);
my $mt = Text::MicroTemplate::File->new(
    include_path => [$path],
    cache        => 2,
);
my $tt = Template->new(
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.out',
);

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

    plan tests => 3;
    $tt->process("$tmpl.tt", $vars, \my $out) or die $tt->error;
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TT';

    $tcs->process("$tmpl.cs", $vars, \$out);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TCS';

    $out = $mt->render_file("$tmpl.mt", $vars);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'MT';
}

# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render("$tmpl.tx", $vars)];
        return;
    },
    cs => sub{
        my $body = [];
        $tcs->process("$tmpl.cs", $vars, \$body->[0]);
        return;
    },
    mt => sub {
        my $body = [$mt->render_file("$tmpl.mt", $vars)];
        return;
    },
    tt => sub{ 
        my $body = [];
        $tt->process("$tmpl.tt", $vars, \$body->[0]) or die $tt->error;
        return;
    },
};

