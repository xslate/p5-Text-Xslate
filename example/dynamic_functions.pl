#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

{
    package MyBridge;

    use parent qw(Text::Xslate::Bridge);

    __PACKAGE__->bridge(
        function => {my_func => \&_my_func},
        scalar   => {my_func => \&_scalar},
        hash     => {my_func => \&_hash},
        array    => {my_func => \&_array},
    );

    sub _scalar {
        my $obj = shift;
        _my_func(@_)->($obj);
    };

    sub _hash {
        my $obj = shift;
        _my_func(@_)->(map {$_, $obj->{$_}} keys %$obj);
    };

    sub _array {
        my $obj = shift;
        _my_func(@_)->(@$obj);
    };

    sub _my_func {
        my @outer_args = @_;
        sub {
            my (@inner_args) = @_;
            join(', ', @outer_args, @inner_args) . "\n";
        }
    }
}

my $tx = Text::Xslate->new(
    module => [qw(MyBridge)],
    path   => $Bin,
);

print $tx->render('dynamic_functions.tx');
