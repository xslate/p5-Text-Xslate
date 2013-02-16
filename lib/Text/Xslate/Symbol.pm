package Text::Xslate::Symbol;
use Mouse;

use Text::Xslate::Util qw(p $DEBUG);

use overload
    bool => sub() { 1 },
    '""' => sub   { $_[0]->id },
    fallback => 1,
;

our @CARP_NOT = qw(Text::Xslate::Parser);

use constant _DUMP_DENOTE => scalar($DEBUG =~ /\b dump=denote \b/xmsi);

has id => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has lbp => ( # left binding power
    is       => 'rw',
    isa      => 'Int',

    lazy     => 1,
    default  => 0,
);

has ubp => ( # unary binding power
    is       => 'rw',
    isa      => 'Int',

    required => 0,
);

has value => (
    is      => 'rw',

    lazy    => 1,
    builder => 'id',
    trigger => sub {
        my($self) = @_;
        $self->is_value(1);
        return;
    },
#    default => sub{
#        if(!defined $_[0]) { #XXX: Mouse::XS's bug
#            my(undef, $file, $line) = caller;
#            warn "[bug] no invocant at $file line $line.\n";
#            return '(null)';
#        }
#        return $_[0]->id
#   },
);

# some tokens have the counterpart token (e.g. '{' to '}')
has counterpart => (
    is  => 'rw',
    isa => 'Str',

    required => 0,
);

# flags
has [
        'is_reserved',     # set by reserve()
        'is_defined',      # set by define()
        'is_block_end',    # block ending markers
        'is_logical',      # logical operators
        'is_comma',        # comma like operators
        'is_value',        # symbols with values
        'is_statement',    # expr but a statement (e.g. assignment)
        'can_be_modifier', # statement modifiers (e.g. expr if cond)
    ] => (
    is       => 'rw',
    isa      => 'Bool',
    required => 0,
);

has nud => ( # null denotation
    is  => 'bare',
    isa => 'CodeRef',

    writer    => 'set_nud',
    reader    => 'get_nud',
    predicate => 'has_nud',
    clearer   => 'remove_nud',

    trigger => sub{
        my($self) = @_;
        $self->is_value(1);
        return;
    },

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

    required => 0,
);

has assignment => (
    is  => 'rw',
    isa => 'Bool',

    required => 0,
);

#has scope => (
#    is  => 'rw',
#    isa => 'HashRef',
#
#    required => 0,
#);

has line => (
    is  => 'rw',
    isa => 'Int',

    lazy    => 1,
    default => 0,
);


sub _build_nud {
    return \&_nud_default;
}

sub _build_led {
    return \&_led_default;
}

sub _build_std {
    return \&_std_default;
}

sub _nud_default {
    my($parser, $symbol) = @_;
    return $parser->default_nud($symbol);
}

sub _led_default {
    my($parser, $symbol) = @_;
    return $parser->default_led($symbol);
}

sub _std_default {
    my($parser, $symbol) = @_;
    return $parser->default_std($symbol);
}

sub nud {
    my($self, $parser, @args) = @_;
    $self->_dump_denote('nud', $parser) if _DUMP_DENOTE;
    return $self->get_nud()->($parser, $self, @args);
}

sub led {
    my($self, $parser, @args) = @_;
    $self->_dump_denote('led', $parser) if _DUMP_DENOTE;
    return $self->get_led()->($parser, $self, @args);
}

sub std {
    my($self, $parser, @args) = @_;
    $self->_dump_denote('std', $parser) if _DUMP_DENOTE;
    return $self->get_std()->($parser, $self, @args);
}

sub clone {
    my $self = shift;
    return $self->meta->clone_object($self, @_);
}

sub _dump_denote {
    my($self, $type, $parser) = @_;
    my $attr = $self->meta->get_attribute($type);

    my $entity = $attr->has_value($self)
        ? $attr->get_value($self)
        : $parser->can('default_' . $type);

    require B;
    my $cvgv = B::svref_2object($entity)->GV;
    printf STDERR "%s: %s::%s (%s:%s)\n",
        $type,
        $cvgv->STASH->NAME, $cvgv->NAME,
        $self->id, $self->line,
    ;
}

no Mouse;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::Symbol - The symbol representation used by parsers and compilers

=cut

