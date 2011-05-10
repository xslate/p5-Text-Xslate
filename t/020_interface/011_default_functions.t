#!perl -w
use strict;
use Test::More;
use Text::Xslate;

{
    package MyXslate;
    use parent qw(Text::Xslate);

    sub default_functions {
        return {
            foo     => sub { 'bar' },
            blessed => sub { 42 },
        };
    }
}

my $tx = MyXslate->new(
    module => [qw(Scalar::Util) => [qw(blessed)]],
);

is $tx->render_string('<: foo() :>'), 'bar';
is $tx->render_string('<: blessed($o) :>', { o => bless {}, 'XYZ' }), 'XYZ';


done_testing;

