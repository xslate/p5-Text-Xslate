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

        $self->symbol('merge_hash')->set_nud($self->can('nud_merge_hash'));
    }

    sub nud_merge_hash {
        my $self = shift;
        my ($symbol) = @_;

        $self->advance('(');
        my $base = $self->expression(0);
        $self->advance(',');
        my $value = $self->expression(0);
        $self->advance(')');

        return $symbol->clone(
            arity  => 'merge_hash',
            first  => $base,
            second => $value,
        );
    }

    package Text::Xslate::Compiler::Custom;
    use Mouse;
    extends 'Text::Xslate::Compiler';

    sub _generate_merge_hash {
        my $self = shift;
        my ($node) = @_;

        my $lvar_id = $self->lvar_id;
        local $self->{lvar_id} = $self->lvar_use(1);

        return (
            $self->compile_ast($node->first),
            $self->opcode('save_to_lvar', $lvar_id),
            $self->compile_ast($node->second),
            $self->opcode('move_to_sb'),
            $self->opcode('load_lvar', $lvar_id),
            $self->opcode('merge_hash'),
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

my @tests = (
    [ ': [ merge_hash($a, $b).foo, $a.foo, $b.foo ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'FOO FOO undef' ],
    [ ': [ merge_hash($b, $a).foo, $a.foo, $b.foo ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'FOO FOO undef' ],
    [ ': [ merge_hash($a, $b).bar, $a.bar, $b.bar ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'RAB BAR RAB' ],
    [ ': [ merge_hash($b, $a).bar, $a.bar, $b.bar ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'BAR BAR RAB' ],
    [ ': [ merge_hash($a, $b).baz, $a.baz, $b.baz ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'ZAB undef ZAB' ],
    [ ': [ merge_hash($b, $a).baz, $a.baz, $b.baz ].map(-> $elem { defined($elem) ? $elem : "undef" }).join(" ")', 'ZAB undef ZAB' ],
);

for my $test (@tests) {
    is(
        $tx->render_string(
            $test->[0],
            {
                a => {
                    foo => 'FOO',
                    bar => 'BAR',
                },
                b => {
                    bar => 'RAB',
                    baz => 'ZAB',
                },
            }
        ),
        $test->[1],
        $test->[0]
    );
}

done_testing;
