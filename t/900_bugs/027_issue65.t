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

        $self->symbol('vars')->set_nud($self->can('nud_vars'));
        $self->symbol('localize')->set_std($self->can('std_localize'));
    }

    sub nud_vars {
        my $self = shift;
        my ($symbol) = @_;

        return $symbol->clone(arity => 'vars'),
    }

    sub std_localize {
        my $self = shift;
        my ($symbol) = @_;

        my $name = $self->expression(0);

        $self->advance('{');
        my $body = $self->statements;
        $self->advance('}');

        return $symbol->clone(
            arity => 'block',
            first => [ $name->clone ],
            second => $body,
        ),
    }

    package Text::Xslate::Compiler::Custom;
    use Mouse;
    extends 'Text::Xslate::Compiler';

    sub _generate_block {
        my $self = shift;
        my ($node) = @_;

        my @compiled = map { $self->compile_ast($_) } @{ $node->second };

        unshift @compiled, $self->_localize_vars($node->first);

        return @compiled;
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

    sub _register_builtin_methods {
        my $self = shift;
        my ($funcs) = @_;

        Scalar::Util::weaken(my $weakself = $self);

        $funcs->{include_uc} = sub {
            my ($file, $vars) = @_;
            my $result = $weakself->render($file, $vars);
            return uc($result);
        };

        $self->SUPER::_register_builtin_methods(@_);
    }
}

my $vars = {
    a => "foo",
    b => [
        {
            a => "bar",
            b => [],
        },
    ],
};

my $foo = <<'FOO';
: $a;
: for $b -> $i {
:   localize $i {
:     include_uc("foo", vars);
:   }
: }
FOO

my $tx = Text::Xslate::Custom->new(
    cache => 0,
    path => [{ foo => $foo }],
);

is($tx->render('foo', $vars), 'fooBAR');

done_testing;
