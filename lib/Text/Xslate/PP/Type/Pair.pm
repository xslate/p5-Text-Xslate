package Text::Xslate::PP::Type::Pair;
use Any::Moose;

{
    package
        Text::Xslate::Type::Pair;
    use Any::Moose;
    extends 'Text::Xslate::PP::Type::Pair';
    no Any::Moose;
    __PACKAGE__->meta->make_immutable();
}

has [qw(key value)] => (
    is => 'rw',
);

no Any::Moose;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::PP::Type::Pair - Text::Xslate builtin pair type in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
