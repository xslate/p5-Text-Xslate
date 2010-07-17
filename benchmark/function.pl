#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate qw(build_mt);

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate Text::MicroTemplate)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 100;

my %vpath = (
    function => <<'TX' x $n,
Hello, <:= $lang | uc :> world!
TX
);
my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,

    function => { uc => sub { uc $_[0] } },
);

my $mt = build_mt("Hello, <?= uc(\$_[0]->{lang}) ?> world!\n" x $n);

my $subst_tmpl = qq{Hello, %lang% world!\n} x $n;

my $vars = {
    lang => 'Template',
};

$tx->render(function => $vars) eq $mt->($vars)
    or die $tx->render(function => $vars);

# suppose PSGI response body

cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(function => $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
    's///g' => sub {
        my $body = [$subst_tmpl];
        $body->[0] =~ s/%(\w+)%/uc($vars->{$1})/eg;
        return;
    },
};

