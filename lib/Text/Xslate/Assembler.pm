package Text::Xslate::Assembler;
use Mouse;

has engine => (
    is => 'ro',
    required => 1,
);

sub build {
    my ($class, $engine) = @_;
    $class->new(engine => $engine);
}

sub assemble {
    # XXX taking out ->engine just to pass to _assemble seems a bit like
    # waste, but there history: _assemble initially was part of ::Engine
    # and was written in XS. I don't want to touch the XS part of Xslate
    # with a 40ft pole, but still wanted to rip this apart to a different
    # module. so my solution: place _assemble() in ::Assembler, add
    # a new "self" parameter, and shove engine as the old first parameter
    # (see the XS code that goes along with this)
    my $self = shift;
    $self->_assemble($self->engine, @_);
}

1;

