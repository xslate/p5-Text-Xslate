#!perl -w
use strict;
use Test::More;
use Text::Xslate;

{
    package Foo;
    use Any::Moose;

    has bar => (
        is  => 'rw',
        isa => 'Int',
    );

    package MyXslate;
    our @ISA = qw(Text::Xslate);

    sub render_string {
        my($self, @args) = @_;
        local $self->{foo} = 'bar';
        return $self->SUPER::render_string(@args);
    }
}

my $tx = MyXslate->new(
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

