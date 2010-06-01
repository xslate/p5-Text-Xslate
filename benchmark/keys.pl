#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate qw(build_mt);

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
use Test::More;

foreach my $mod(qw(Text::Xslate Text::MicroTemplate)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 10;

my $tx = Text::Xslate->new();
$tx->load_string(<<'T' x $n);
: for $h.keys() -> $k {
[<: $k :>]
: }
T

my $mt = build_mt(<<'T' x $n);
? for my $k(sort keys %{ $_[0]->{h} }) {
[<?= $k ?>]
? }
T

my $subst_tmpl = qq{Hello, %value% world!\n} x $n;

my $vars = {
    h => { %ENV },
};

{
    plan tests => 1;
    is $mt->($vars), $tx->render(undef, $vars), 'MT'
        or exit(1);
}
# suppose PSGI response body

cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(undef, $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
};

