#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;

my $tx = Text::Xslate->new(
    function => {
        'array::inc' => sub {
            my($a, $i) = @_;
            $a->[$i]++;
            return $a;
        },
    }
);

my @a = (42);
is $tx->render_string(q{<: $a.merge(3).inc(0).join(',') :>}, { a => \@a}),
    '43,3';
is_deeply \@a, [42];

is $tx->render_string(q{<: $a.merge(3).inc(1).join(',') :>}, { a => \@a}),
    '42,4';

my %h = (foo => 42);
is $tx->render_string(q{<: $h.keys().inc(0).join(',') :>}, { h => \%h}),
    do{ my $x = 'foo'; $x++; $x };
is_deeply \%h, { foo => 42 };

is $tx->render_string(q{<: $h.values().inc(0).join(',') :>}, { h => \%h}),
    '43';
is_deeply \%h, { foo => 42 };

done_testing;
