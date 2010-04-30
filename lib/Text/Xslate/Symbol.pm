package Text::Xslate::Symbol;
use 5.010;
use Mouse;

use overload
    '""' => sub{ $_[0]->id },
    fallback => 1,
;

our @CARP_NOT = qw(Text::Xslate::Parser);

has id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has lbp => (
    is       => 'rw',
    isa      => 'Int',

    lazy     => 1,
    default  => 0,
);

has value => (
    is      => 'rw',

    lazy    => 1,
    default => sub{ $_[0]->id },
);

has nud => ( # null denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_nud',
    reader    => 'get_nud',
    predicate => 'has_nud',
    clearer   => 'remove_nud',

    required => 0,
);

has led => ( # left denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_led',
    reader    => 'get_led',
    predicate => 'has_led',
    clearer   => 'remove_led',

    required => 0,
);

has std => ( # statement denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_std',
    reader    => 'get_std',
    predicate => 'has_std',
    clearer   => 'remove_std',

    required => 0,
);


has [qw(first second third)] => (
    is  => 'rw',

    required => 0,
);

has type => (
    is  => 'rw',
    isa => 'Str',

    required => 0,
);

has arity => (
    is  => 'rw',
    isa => 'Str',

    lazy    => 1,
    default => 'symbol',

    required => 0.
);

has assignment => (
    is  => 'rw',
    isa => 'Bool',

    required => 0,
);

has reserved => (
    is  => 'rw',
    isa => 'Bool',

    required => 0,
);

#has scope => (
#    is  => 'rw',
#    isa => 'HashRef',
#
#    weak_ref => 1,
#
#    required => 0,
#);

has line => (
    is  => 'ro',
    isa => 'Int',

    required => 0,
);

sub nud {
    my($self, $parser) = @_;

    if(!$self->has_nud) {
        $parser->near_token($parser->token);
        $parser->_error(
            sprintf 'Undefined symbol (%s): %s',
            $self->arity, $self->id);
    }

    return $self->get_nud()->($parser, $self);
}

sub led {
    my($self, $parser, $left) = @_;

    if(!$self->has_led) {
        $parser->near_token($parser->token);
        $parser->_error(
            sprintf 'Missing operator (%s): %s',
            $self->arity, $self->id);
    }

    return $self->get_led()->($parser, $self, $left);
}

sub std {
    my($self, $parser) = @_;

    if(!$self->has_std) {
        $parser->_error(
            sprintf 'Not a statement (%s): %s',
            $self->arity, $self->id);
    }

    return $self->get_std()->($parser, $self);
}

sub clone {
    my $self = shift;
    return $self->meta->clone_object($self, @_);
}

no Mouse;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::Symbol - The symbol representation used by parsers

=cut

