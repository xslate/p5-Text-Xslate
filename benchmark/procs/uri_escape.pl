#!perl -w
use strict;

use Text::Xslate;

use URI::Escape;
use URI::Escape::XS;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate URI::Escape URI::Escape::XS)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 100;

my %vpath = (
    builtin_uri => <<'TX' x $n,
Hello, <: $lang | uri :> world!
TX
    uri_escape_pp => <<'TX' x $n,
Hello, <: $lang | uri_pp :> world!
TX

    uri_escape_xs => <<'TX' x $n,
Hello, <: $lang | uri_xs :> world!
TX

);
my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,

    function => {
        uri_pp => \&uri_escape,
        uri_xs => \&encodeURIComponent,
    },
);

my $vars = {
    lang => '/Text::Xslate/',
};

{
    use Test::More;
    plan tests => 2;
    is $tx->render(uri_escape_pp => $vars), $tx->render(builtin_uri => $vars), 'URI::Escape';
    is $tx->render(uri_escape_xs => $vars), $tx->render(builtin_uri => $vars), 'URI::Escape:XS';
}

# suppose PSGI response body
cmpthese -1 => {
    builtin => sub {
        my $body = [$tx->render(builtin_uri => $vars)];
    },
    'URI::Escape' => sub {
        my $body = [$tx->render(uri_escape_pp => $vars)];
    },
    'URI::Escape::XS' => sub {
        my $body = [$tx->render(uri_escape_xs => $vars)];
    },
};

