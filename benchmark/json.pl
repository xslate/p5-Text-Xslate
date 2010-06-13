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

my $tx = Text::Xslate->new();
$tx->load_string(<<'TX_END');
<ul>
: for $books ->($item) {
    <li><:= $item.title :> (<: $item.author :>)</li>
: }
</ul>
TX_END

my $json = JSON::XS->new();

my %vars = (
     books => [(
        { title  => 'Islands in the stream',
          author => 'Ernest Hemingway' },
        { title  => 'Beautiful code',
          author => 'Brian Kernighan, Jon Bentley, et. al.' },
        { title  => q{Atkinson and Hilgard's Introduction to Psychology With Infotrac}, # '
          author => 'Edward E. Smith, et. al.' },
        { title => 'Programming Perl',
          author => 'Larry Wall, et.al.' },
        { title => 'Compilers: Principles, Techniques, and Tools',
          author => 'Alfred V. Aho, et. al.' },
     ) x $n],
);

if(0) {
    print $tx->render(undef, \%vars);
    print $json->encode(\%vars);
}

cmpthese -1 => {
    xslate => sub {
        my $body = $tx->render(undef, \%vars);
        return;
    },
    json => sub {
        my $body = $json->encode(\%vars);
        return;
    },
};
