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
    fib => <<'TX',
: macro fib -> $n {
:     $n <= 1 ? 1 : fib($n - 1) + fib($n - 2);
: }
: fib($x);
TX
);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my $mt = build_mt(<<'MT');
? sub fib {
?     my($n) = @_;
?     $n <= 1 ? 1 : fib($n - 1) + fib($n - 2);
? }
?= fib($_[0]->{x})
MT

my $vars = {
    x => $n,
};

{
    plan tests => 1;
    my $out = $mt->($vars);
    chomp $out;
    is $out, $tx->render(fib => $vars), 'MT'
        or die;
}
# suppose PSGI response body
print "fib($n) = ", $tx->render(fib => $vars), "\n";
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(fib => $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
};

