package Text::Xslate::PP::Compiler;
use Any::Moose;
use Any::Moose '::Util::TypeConstraints';

use Text::Xslate::Util qw(value_to_literal);
use Text::Xslate::PP::Compiler::CodeGenerator;

extends qw(Text::Xslate::Compiler);

# Perl interpreter does constant folding, so PP::Compiler need not do it.
sub _fold_constants { 0 }

sub compile {
    my $self = shift;
    my $asm  = $self->SUPER::compile(@_);

    my $generator =Text::Xslate::PP::Compiler::CodeGenerator->new();
    my $perlcode = $generator->opcode_to_perlcode_string( $asm );

    unshift @{$asm}, $self->opcode('_ppbooster' => $perlcode);

    return $asm;
}

no Any::Moose;
no Any::Moose '::Util::TypeConstraints';

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::PP::Compiler - An Xslate compiler for PP::Booster

=head1 DESCRIPTION

This is the Xslate compiler to generate the intermediate code from the
abstract syntax tree that parsers build from templates.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Parser>

L<Text::Xslate::PP>

L<Text::Xslate::PP::Booster>

=cut
