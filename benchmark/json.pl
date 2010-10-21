#!perl -w
use strict;

use Text::Xslate;
use JSON::XS;

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate JSON::XS)){
    print $mod, '/', $mod->VERSION, "\n";
}

my $n = shift(@ARGV) || 10;

my %vpath = (
    json => <<'TX',
<ul>
: for $books ->($item) {
    <li><:= $item.title :> (<: $item.author :>)</li>
: }
</ul>
TX
);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.xslate_cache',
    cache     => 2,
);

my $json = JSON::XS->new();

my %vars = (
     books => [(
        { title  => 'Islands in the stream',
          author => 'Ernest Hemingway' },
        { title  => 'Beautiful code',
          author => 'Brian Kernighan, Jon Bentley, et. al.' },
        { title  => q{Atkinson and Hilgard's Introduction to Psychology With Infotrac}, # '
          author => 'Edward E. Smith, et. al.' },
        { title  => 'Programming Perl',
          author => 'Larry Wall, et.al.' },
        { title  => 'Compilers: Principles, Techniques, and Tools',
          author => 'Alfred V. Aho, et. al.' },
     ) x $n],
);

if(0) {
    print $tx->render(json => \%vars);
    print $json->encode(\%vars);
}

cmpthese -1 => {
    xslate => sub {
        my $body = $tx->render(json => \%vars);
        return;
    },
    json => sub {
        my $body = $json->encode(\%vars);
        return;
    },
};
