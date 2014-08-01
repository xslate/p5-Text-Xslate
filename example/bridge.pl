#!perl -w
use strict;
use Text::Xslate;
use FindBin qw($Bin);

{
    package MyBridge;

    use parent qw(Text::Xslate::Bridge);

    use Scalar::Util qw(looks_like_number);
    use List::Util qw(sum);

    __PACKAGE__->bridge(
        scalar => {
            looks_like_number => \&_scalar_looks_like_number,
            length => \&_scalar_length,
        },
        array => {
            sum => \&_array_sum,
        },
        hash => {
            delete_keys => \&_hash_delete_keys,
        },

    );

    sub _scalar_looks_like_number {
        looks_like_number($_[0]);
    }

    sub _scalar_length {
        defined $_[0] ? length $_[0] : 0;
    }

    sub _array_sum {
        defined $_[0] ? sum @{$_[0]} : 0;
    }

    sub _hash_delete_keys {
        my %hash = %{+shift};
        delete $hash{$_} for @_;
        return \%hash;
    }
}

my $tx = Text::Xslate->new(
    module => [qw(MyBridge)],
    path   => $Bin,
);

print $tx->render('bridge.tx');
