package Text::Xslate::Compiler::HTP;
use warnings FATAL => 'recursion';
use Any::Moose;

extends qw(Text::Xslate::Compiler);

sub _generate_call {
    my($self, $node) = @_;
    my $callable = $node->first; # function or macro
    my $args     = $node->second;

    my @code = $self->SUPER::_generate_call($node);

    if($callable->arity eq 'name'){
        my @code_fetch_symbol = $self->compile_ast($callable);
        @code = (
            $self->opcode( pushmark => undef, comment => $callable->id ),
            (map { $self->push_expr($_) } @{$args}),

            $self->opcode( fetch_s => $callable->value, line => $callable->line ),
            $self->opcode( 'or' => scalar(@code_fetch_symbol) + 1),

            @code_fetch_symbol,
            $self->opcode( 'funcall' )
        );
    };
    @code;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable();
