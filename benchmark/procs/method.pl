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

{
    package Pair;
    use Mouse;

    has [qw(key value)] => (
        is => 'rw',
    );
    __PACKAGE__->meta->make_immutable();
}

my %vpath = (
    accessor => <<'TX' x $n,
: for $data -> $v {
[<: $v.key :>]=[<: $v.value :>]
: }
TX

    method => <<'TX' x $n,
: for $data -> $v {
[<: $v.key() :>]=[<: $v.value() :>]
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
? for my $v(@{$data}) {
[<?= $v->key ?>]=[<?= $v->value ?>]
? }
? }
T

my $vars = {
    data => [ map { Pair->new(key => $_, value => $ENV{$_}) } keys %ENV ],
    #data => [ map { +{ key => $_, value => $ENV{$_} } } keys %ENV ],
};

{
    plan tests => 1;
    is $mt->($vars), $tx->render(method => $vars), 'MT'
        or exit(1);
}
# suppose PSGI response body
print "xslate/1 as field access, xslate/2 as method call, MT as method call\n";
cmpthese -1 => {
    'xslate/1' => sub {
        my $body = [$tx->render(accessor => $vars)];
        return;
    },
    'xslate/2' => sub {
        my $body = [$tx->render(method => $vars)];
        return;
    },
    MT => sub {
        my $body = [$mt->($vars)];
        return;
    },
};

