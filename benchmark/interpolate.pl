#!perl -w
use strict;

use Text::Xslate;
use Text::MicroTemplate qw(build_mt);

use Benchmark qw(:all);

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};
foreach my $mod(qw(Text::Xslate Text::MicroTemplate)){
    print $mod, '/', $mod->VERSION, "\n";
}

my($n, $data) = @ARGV;
$n    ||= 100;
$data ||= 10;

my %vpath = (
    interpolate => <<'TX' x $n,
Hello, <:= $lang :> world!
TX

    interpolate_raw => <<'TX' x $n,
Hello, <:= $lang | raw :> world!
TX

);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my $mt = build_mt("Hello, <?= \$_[0]->{lang} ?> world!\n" x $n);

my $subst_tmpl = qq{Hello, %lang% world!\n} x $n;

my $sprintf_tmpl = qq{Hello, %1\$s world!\n} x $n;

my $vars = {
    lang => 'Template' x $data,
};
printf "template size: %d bytes; data size: %d bytes\n",
    length $vpath{interpolate}, length $vars->{lang};

{
    use Test::More;
    plan tests => 4;
    my $x = $tx->render(interpolate => $vars);
    is $tx->render(interpolate_raw => $vars), $x, 'xslate/raw (w/o escaping)';
    is $mt->($vars), $x, 'Text::MicroTemplate';
    (my $o = $subst_tmpl) =~ s/%(\w+)%/$vars->{$1}/g;
    is $o, $x, 's///g';
    is sprintf($sprintf_tmpl, $vars->{lang}), $x, 'sprintf';
}

# suppose PSGI response body

cmpthese -1 => {
    xslate => sub {
        my $body = [$tx->render(interpolate => $vars)];
        return;
    },
    'xslate/raw' => sub {
        my $body = [$tx->render(interpolate_raw => $vars)];
        return;
    },
    TMT => sub {
        my $body = [$mt->($vars)];
        return;
    },
    's///g' => sub {
        my $body = [$subst_tmpl];
        $body->[0] =~ s/%(\w+)%/$vars->{$1}/g;
        return;
    },
    'sprintf' => sub {
        my $body = [ sprintf $sprintf_tmpl, $vars->{lang} ];
        return;
    },
};

