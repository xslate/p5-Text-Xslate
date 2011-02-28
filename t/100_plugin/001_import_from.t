#!perl -w
use strict;
use Test::More;

use Text::Xslate::Util qw(import_from);

for(1 .. 2) {
    my $f = import_from("Scalar::Util" => [qw(blessed looks_like_number)]);

    is_deeply $f, {
            blessed           => \&Scalar::Util::blessed,
            looks_like_number => \&Scalar::Util::looks_like_number,
    };

    $f = import_from(
        "Carp",
        "Data::Dumper" => [qw(Dumper)],
    );

    is_deeply $f, {
            Dumper   => \&Data::Dumper::Dumper,
            carp     => \&Carp::carp,
            croak    => \&Carp::croak,
            confess  => \&Carp::confess,
    };

    # for constants
    $f = import_from(
           "Fcntl" => [qw(:flock)],
    );

    ok exists $f->{LOCK_EX} or diag explain($f);
    is $f->{LOCK_EX}->(), Fcntl::LOCK_EX(), 'constant';
    is $f->{LOCK_SH}->(), Fcntl::LOCK_SH(), 'constant';
}


done_testing;
