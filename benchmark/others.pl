#!perl -w
use 5.010;
use strict;

use Text::Xslate;
use Text::ClearSilver;
use Text::MicroTemplate;
use Template;

use Test::More;
use Benchmark qw(:all);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate Text::ClearSilver Template)){
    say $mod, '/', $mod->VERSION;
}

my $n = shift(@ARGV) || 100;

my $x = Text::Xslate->new(string => <<'T' x $n);
Hello, <:= $foo :> world!
Hello, <:= $bar :> world!
Hello, <:= $baz :> world!
T

my $tcs = Text::ClearSilver->new(VarEscapeMode => 'html');
my $mt  = Text::MicroTemplate::build_mt(<<'T' x $n);
Hello, <?= $_[0]->{foo} ?> world!
Hello, <?= $_[0]->{bar} ?> world!
Hello, <?= $_[0]->{baz} ?> world!
T

my $vars = {
    foo => 'FOO',
    bar => 'BAR',
    baz => 'BAZ',
};

$x->render($vars) eq $mt->($vars) or die "render error: ", $x->render($vars);

my $tcs_tmpl = <<'T' x $n;
Hello, <?cs var:foo ?> world!
Hello, <?cs var:bar ?> world!
Hello, <?cs var:baz ?> world!
T

my $fmt = <<'T' x $n;
Hello, %1$s world!
Hello, %2$s world!
Hello, %3$s world!
T

my $tt = Template->new();
my $tt_tmpl = <<'T' x $n;
Hello, [% foo %] world!
Hello, [% bar %] world!
Hello, [% baz %] world!
T

{
    plan tests => 3;
    $tt->process(\$tt_tmpl, $vars, \my $out) or die $tt->error;
    is $x->render($vars), $out, 'Xslate eq TT';

    $tcs->process(\$tcs_tmpl, $vars, \$out);
    is $x->render($vars), $out, 'Xslate eq TCS';

    is $x->render($vars), $mt->($vars), 'Xslate eq MT';
}

# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$x->render($vars)];
        return;
    },
    clearsilver => sub{
        my $body = [];
        $tcs->process(\$tcs_tmpl, $vars, \$body->[0]);
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
    tt => sub{ 
        my $body = [];
        $tt->process(\$tt_tmpl, $vars, \$body->[0]) or die $tt->error;
        return;
    },
    sprintf => sub {
        my $body = [sprintf $fmt, @{$vars}{qw(foo bar baz)}];
        return;
    },
};

