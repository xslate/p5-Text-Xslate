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

        $self->symbol('suffix')->set_nud($self->can('nud_suffix'));
    }

    sub nud_suffix {
        my $self = shift;
        my ($symbol) = @_;

        return $symbol->clone(arity => 'suffix'),
    }

    package Text::Xslate::Compiler::Custom;
    use Mouse;
    extends 'Text::Xslate::Compiler';

    sub _generate_suffix {
        my $self = shift;
        my ($node) = @_;

        return (
            $self->opcode('suffix'),
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

my $tx = Text::Xslate::Custom->new(suffix => '.mustache');

is(
    $tx->render_string(
        ': suffix;',
        {}
    ),
    '.mustache',
    "got the right suffix"
);

done_testing;
