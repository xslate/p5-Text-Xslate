#!perl -w
use strict;
use Test::More;
use Text::Xslate;

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

done_testing;

