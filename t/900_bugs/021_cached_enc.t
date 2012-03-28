#!perl
# there were mojibake when caches were used
use strict;
use warnings;

use Text::Xslate;

#use if !Text::Xslate->USE_XS,
#    'Test::More', skip_all => 'PP impl differs from XS impl';

use Test::More;
use File::Temp qw(tempdir);
use Encode qw(decode);

binmode $_, 'utf8' for
    \*STDOUT,
    \*STDERR,
    Test::More->builder->output,
    Test::More->builder->failure_output,
    Test::More->builder->todo_output;


sub d {
    return decode('utf8', shift);
}

my %vpath = (
    'layout.tx' => d(<<'T'),
<p>
: block content -> {}
</p>
T
    foo => d(<<'T'),
: cascade layout;

: around content -> {
<em><: $bar :></em>
: }
T
);

my $tmpdir = tempdir(DIR => ".", CLEANUP => 1);

my %opts = (
    path      => \%vpath,
    cache     => 1,
    cache_dir => $tmpdir,
);
my %vars = (
    bar => ('こんにちは'),
);

my $expected = d(<<'T');
<p>
<em>こんにちは</em>
</p>
T

note 'utf-8 encoded bytes';
foreach my $i(1 .. 2) {
    my $tx = Text::Xslate->new(\%opts);

    for my $j(1 .. 2) {
    is $tx->render(foo => \%vars),
        $expected, "process $i, render $j";
    }
}

$tmpdir = tempdir(DIR => ".", CLEANUP => 1);

note 'text string';
utf8::decode($vars{bar});
foreach my $i(1 .. 2) {
    my $tx = Text::Xslate->new(\%opts);

    for my $j(1 .. 2) {
    is $tx->render(foo => \%vars),
        $expected, "process $i, render $j";
    }
}

undef $tmpdir;

done_testing;

