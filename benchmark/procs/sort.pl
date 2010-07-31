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

my %vpath = (
    sort => <<'TX' x $n,
: for $data.sort(-> $a, $b { $a.value <=> $b.value }) -> $v {
[<: $v.value :>]
: }
TX
);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my $mt = build_mt(<<'T' x $n);
? {
? my $data = $_[0]->{data};
? for my $v(sort { $a->{value} <=> $b->{value} } @{$data}) {
[<?= $v->{value} ?>]
? }
? }
T

my $vars = {
    data => [ map { +{ value => $_ } } reverse 1 .. 100 ],
};

{
    plan tests => 1;
    is $mt->($vars), $tx->render(sort => $vars), 'MT'
        or exit(1);
}
# suppose PSGI response body
print q{Benchmark of sort-by-values ($a.sort( -> $a, $b { $a.value <=> $b.value })):}, "\n";
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(sort => $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
};

