#!/usr/bin/perl -wT
# Taint flag breaks template for-loop parsing:
# https://rt.cpan.org/Public/Bug/Display.html?id=61359

use strict;
use Test::More;

use Text::Xslate;
use Scalar::Util qw(tainted);


use lib "t/lib";
use Util;

my $dataset = {
    scalar_variable => 'twinkle twinkle little scalar',
    hash_variable   => {
        'hash_value_key' =>
            'ha-ha-ha-hash',
        },
    array_variable   => [ qw/this is an array/ ],
    this => { is => { a => { very => { deep => { hash => {
        structure => "scraping the bottom of the hashref",
        } } } } } },
    template_if_true  => 'yay',
    template_if_false => 'nope',

    array_loop =>
        [ qw/do ray me so fah/ ],
    hash_loop  => {
        animal    => 'camel',
        mineral   => 'lignite',
        vegetable => 'ew',
        },
    records_loop => [
        { name => 'Larry Nomates', age => 43,  },
        ],
    variable_if      => 0,
    variable_if_else => 1,
    variable_expression_a => 200,
    variable_expression_b => 100,
    variable_function_arg => 'BzzZZzzZZzzZZzzZZ',
};

my $gold = do { local $/; <DATA> };

my $t = Text::Xslate->new(
    path      => [path],
    cache     => 0,
    function  => {
            substr => sub { substr( $_[ 0 ], $_[ 1 ], $_[ 2 ] ) },
        },
    warn_handler => sub { die @_ },
    );

my $s = $t->render( 'taint.tx', $dataset );
ok !tainted($s), 'not tainted';
is $s, $gold;

# taint $gold
foreach my $value(values %{$dataset}) {
    $value .= substr($^X, 0, 0) if not ref($value);
}
is $t->render( 'taint.tx', $dataset ), $gold;

done_testing;
__END__
foo foo foo foo foo foo foo foo foo foo foo foo
foo foo foo foo foo foo foo foo foo foo foo foo
foo foo foo foo foo foo foo foo foo foo foo foo
foo foo foo foo foo foo foo foo foo foo foo foo
foo foo foo foo foo foo foo foo foo foo foo foo
twinkle twinkle little scalar
ha-ha-ha-hash
an
scraping the bottom of the hashref
doraymesofah

    animal: camel

    mineral: lignite

    vegetable: ew


    Larry Nomates: 43


    do

    ray

    me

    so

    fah


    animal: camel

    mineral: lignite

    vegetable: ew


    Larry Nomates: 43

true

true
true
yay

yay
yay
22
20000
201
substring
Zz
