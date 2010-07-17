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

my $n = shift(@ARGV) || 100;

my %vpath = (
    expr => "Hello, <:=  \$value + 1 :> world!\n" x $n,
);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my $mt = build_mt(qq{Hello, <?= \$_[0]->{value} + 1 ?> world!\n} x $n);

my $subst_tmpl = qq{Hello, %value% world!\n} x $n;

my $vars = {
    value => '41',
};

{
    plan tests => 2;
    my $expected = $tx->render(expr => $vars);
    is $mt->($vars), $expected, 'MT';

    my $body = [$subst_tmpl];
    $body->[0] =~ s/%(\w+)%/ $vars->{$1} + 1 /eg;
    is $body->[0], $expected, 's///g';
}

# suppose PSGI response body
cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(expr => $vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
    's///g' => sub {
        my $body = [$subst_tmpl];
        $body->[0] =~ s/%(\w+)%/ $vars->{$1} + 1 /eg;
        return;
    },
};

