#!perl -w
use strict;
use Test::More;
use Text::Xslate;

{
    package Foo;
    use Mouse;

    has bar => (
        is  => 'rw',
        isa => 'Int',
    );
}

my $tx = Text::Xslate->new(
    module       => [qw(Carp) => [qw(confess croak)] ],
    warn_handler => sub { die @_ },
);

eval {
    $tx->render_string('<: croak("foo") :>');
};
like $@, qr/foo/, 'croak in functions';

eval {
    $tx->render_string('<: confess("bar") :>');
};
like $@, qr/bar/, 'confess in templates';

eval {
    $tx->render_string('<: $foo.bar("xyzzy") :>', { foo => Foo->new });
};
like $@, qr/Validation failed/, 'confess in templates';
done_testing;

