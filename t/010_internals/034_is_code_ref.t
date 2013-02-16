#!perl
use strict;
use warnings;
use Test::More;

use Text::Xslate;

BEGIN {
    package Text::Xslate::Syntax::Custom;
    use Mouse;
    extends 'Text::Xslate::Parser';

    sub init_symbols {
        my $self = shift;

        $self->SUPER::init_symbols(@_);

        $self->symbol('is_code_ref')->set_nud($self->can('nud_is_code_ref'));
    }

    sub nud_is_code_ref {
        my $self = shift;
        my ($symbol) = @_;

        $self->advance('(');
        my $expr = $self->expression(0);
        $self->advance(')');

        return $symbol->clone(arity => 'is_code_ref', first => $expr),
    }

    package Text::Xslate::Compiler::Custom;
    use Mouse;
    extends 'Text::Xslate::Compiler';

    sub _generate_is_code_ref {
        my $self = shift;
        my ($node) = @_;

        return (
            $self->compile_ast($node->first),
            $self->opcode('is_code_ref'),
        );
    }

    package Text::Xslate::Custom;
    use base 'Text::Xslate';

    sub options {
        my $class = shift;

        my $options = $class->SUPER::options(@_);

        $options->{compiler} = 'Text::Xslate::Compiler::Custom';
        $options->{syntax}   = 'Custom';

        return $options;
    }
}

my $tx = Text::Xslate::Custom->new;

is(
    $tx->render_string(
        ': is_code_ref($a) ? "yes" : "no";',
        { a => sub { } }
    ),
    'yes',
    "is a code ref"
);

is(
    $tx->render_string(
        ': is_code_ref($a) ? "yes" : "no";',
        { a => 'sub' }
    ),
    'no',
    "isn't a code ref"
);

done_testing;
