#!perl -w
use 5.010;
use strict;

use Text::Xslate;
use Text::ClearSilver;
use Text::MicroTemplate;
use Template;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate Text::MicroTemplate Text::ClearSilver Template)){
    say $mod, '/', $mod->VERSION;
}

my $n = shift(@ARGV) || 10;

my $x = Text::Xslate->new(string => <<'T' x $n);
Hello, <?= $lang ?> world!
T

my $tcs = Text::ClearSilver->new();
my $mt  = Text::MicroTemplate::build_mt(
    "Hello, <?= \$_[0]->{lang} ?> world!\n" x $n
);
my $vars = {
    lang => 'Template',
};

$x->render($vars) eq $mt->($vars) or die "render error: ", $x->render($vars);

my $tcs_tmpl = <<'T' x $n;
Hello, <?cs var:lang ?> world!
T

my $fmt = <<'T' x $n;
Hello, %1$s world!
T

my $tt = Template->new();
my $tt_tmpl = <<'T' x $n;
Hello, [% lang %] world!
T
{
    $tt->process(\$tt_tmpl, $vars, \my $out) or die $tt->error;
    $out eq $x->render($vars) or die "render error: ", $out;
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
        my $body = [sprintf $fmt, $vars->{lang}];
        return;
    },
};

