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
$tx->load_string(<<'TX');
: macro fib -> $n {
:     $n <= 1 ? 1 : fib($n - 1) + fib($n - 2);
: }
: fib($x);
TX

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
    is $out, $tx->render(undef, $vars), 'MT'
        or die;
}
# suppose PSGI response body
print "fib($n) = ", $tx->render(undef, $vars), "\n";
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

