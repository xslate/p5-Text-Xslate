package Text::Xslate::PP::Type::Macro;
use Mouse;
use warnings FATAL => 'recursion';

use overload
    '&{}'    => \&as_code_ref,
    fallback => 1,
;

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

has state => (
    is  => 'rw',
    isa => 'Object',

    required => 1,
    weak_ref => 1,
);

sub as_code_ref {
    my($self) = @_;

    return sub {
        my $st = $self->state;
        push @{$st->{SP}}, [@_];
        $st->proccall($self);
    };
}

no Mouse;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::PP::Type::Macro - Text::Xslate macro object in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
