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

        $self->symbol('find_file')->set_nud($self->can('nud_find_file'));
    }

    sub nud_find_file {
        my $self = shift;
        my ($symbol) = @_;

        $self->advance('(');
        my $expr = $self->expression(0);
        $self->advance(')');

        return $symbol->clone(arity => 'find_file', first => $expr),
    }

    package Text::Xslate::Compiler::Custom;
    use Mouse;
    extends 'Text::Xslate::Compiler';

    sub _generate_find_file {
        my $self = shift;
        my ($node) = @_;

        return (
            $self->compile_ast($node->first),
            $self->opcode('find_file'),
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

my $tx = Text::Xslate::Custom->new(path => [ { 'exists.tx' => '' } ]);

is(
    $tx->render_string(
        ': find_file($a) ? "yes" : "no";',
        { a => 'exists.tx' }
    ),
    'yes',
    "file exists"
);

is(
    $tx->render_string(
        ': find_file($a) ? "yes" : "no";',
        { a => 'does_not_exist.tx' }
    ),
    'no',
    "file doesn't exist"
);

done_testing;
