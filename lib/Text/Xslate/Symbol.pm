package Text::Xslate::Symbol;
use 5.010;
use Mouse;

use overload
    '""' => sub{ $_[0]->id },
    fallback => 1,
;

our @CARP_NOT = qw(Text::Xslate::Parser);

has id => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has lbp => (
    is       => 'rw',
    isa      => 'Int',

    lazy     => 1,
    default  => 0,
);

has ubp => (
    is       => 'rw',
    isa      => 'Int',

    required => 0,
);

has value => (
    is      => 'rw',

    lazy    => 1,
    builder => 'id',
#    default => sub{
#        if(!defined $_[0]) { #XXX: Mouse::XS's bug
#            my(undef, $file, $line) = caller;
#            warn "[bug] no invocant at $file line $line.\n";
#            return '(null)';
#        }
#        return $_[0]->id
#   },
);

has is_end => (
    is  => 'rw',
    isa => 'Bool',

    required => 0,
);

has is_logical => (
    is  => 'rw',
    isa => 'Bool',

    required => 0,
);

has nud => ( # null denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_nud',
    reader    => 'get_nud',
    predicate => 'has_nud',
    clearer   => 'remove_nud',

    lazy_build => 1,

    required => 0,
);

has led => ( # left denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_led',
    reader    => 'get_led',
    predicate => 'has_led',
    clearer   => 'remove_led',

    lazy_build => 1,

    required => 0,
);

has std => ( # statement denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_std',
    reader    => 'get_std',
    predicate => 'has_std',
    clearer   => 'remove_std',

    lazy_build => 1,

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
    default => 'name',

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


sub _build_nud {
    my($self) = @_;
    return $self->can('_nud_default');
}

sub _build_led {
    my($self) = @_;
    return $self->can('_led_default');
}

sub _build_std {
    my($self) = @_;
    return $self->can('_std_default');
}

sub _nud_default {
    my($parser, $symbol) = @_;
    $parser->near_token($parser->token);
    $parser->_error(
        sprintf 'Undefined symbol (%s): %s',
        $symbol->arity, $symbol->id);
}

sub _led_default {
    my($parser, $symbol) = @_;
    $parser->near_token($parser->token);
    $parser->_error(
        sprintf 'Missing operator (%s): %s',
        $symbol->arity, $symbol->id);
}

sub _std_default {
    my($parser, $symbol) = @_;
    $parser->near_token($parser->token);
    $parser->_error(
        sprintf 'Not a statement (%s): %s',
        $symbol->arity, $symbol->id);
}

sub nud {
    my($self, $parser) = @_;
    return $self->get_nud()->($parser, $self);
}

sub led {
    my($self, $parser, $left) = @_;
    return $self->get_led()->($parser, $self, $left);
}

sub std {
    my($self, $parser) = @_;
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

