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

sub _generate_variable {
    my($self, $node) = @_;

    if(defined(my $lvar_id = $self->lvar->{$node->value})) {
        return $self->opcode( load_lvar => $lvar_id, symbol => $node );
    }
    else {
        my $name = $self->_variable_to_value($node);

        my @code;

        my @lvar_name_list =  sort { $self->lvar->{$b} <=> $self->lvar->{$a} } grep { /^\$/ } keys %{$self->lvar};
        my $index = 0;
        foreach my $lvar_name (@lvar_name_list){
            my $skip = 2 + (@lvar_name_list - ++$index)*3; # 3 means 'load_var','fetch_filed_s','or'.
            push(@code,
                 $self->opcode( load_lvar => $self->lvar->{$lvar_name}, symbol => $lvar_name ),
                 $self->opcode( fetch_field_s => $name, line => $node->line ),
                 $self->opcode( or => $skip),
             );
        }
        if($name =~ /~/) {
            $self->_error("Undefined iterator variable $node", $node);
        }
        push(@code, $self->opcode( fetch_s => $name, line => $node->line ));
        @code;
    }
}


no Any::Moose;
__PACKAGE__->meta->make_immutable();
