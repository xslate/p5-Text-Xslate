package Text::Xslate::PP::Macro;
use Any::Moose;

has name => (
    is => 'ro',
    isa => 'Str',

    required => 1,
);

has addr => (
    is => 'ro',
    isa => 'Int',

    required => 1,
);

has nargs => (
    is => 'rw',
    isa => 'Int',

    default => 0,
);

has outer => (
    is => 'rw',
    isa => 'Int',

    default => 0,
);

no Any::Moose;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::PP::Macro - Text::Xslate macro object in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
