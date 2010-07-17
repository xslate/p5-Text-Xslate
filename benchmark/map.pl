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
    map => <<'TX' x $n,
: for $data.map(-> $x { $x + 1 }) -> $v {
[<: $v :>]
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
? for my $v(map{ $_ + 1 } @{$data}) {
[<?= $v ?>]
? }
? }
T

my $vars = {
    data => [ 1 .. 100 ],
};

{
    plan tests => 1;
    is $mt->($vars), $tx->render(map => $vars), 'MT'
        or exit(1);
}
# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(map => $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
};

