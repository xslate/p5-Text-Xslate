package Text::Xslate::Loader;
use Mouse;

with 'Text::Xslate::MakeError';

has assembler => (
    is => 'rw',
);

has engine => ( # XXX Should try to remove dep on engine
    is => 'rw',
);

has magic_template => (
    is => 'rw',
);

has pre_process_handler => (
    is => 'rw',
);

sub extract_config_from_engine {
    # XXX Test::Vars complains if we do ($class, $engine) and not use it
    my (undef, $engine) = @_;
    
    return (
        engine              => $engine,
        assembler           => $engine->_assembler,
        magic_template      => $engine->magic_template,
        pre_process_handler => $engine->{pre_process_handler},
    );
}

sub build {
    my ($class, $engine) = @_;
    my $self = $class->new();
    $self->configure($engine);
    return $self;
}

sub configure {
    my ($self, $engine) = @_;
    my %vars = $self->extract_config_from_engine($engine);
    foreach my $var (keys %vars) {
        $self->$var($vars{$var});
    }
    return $self;
}

sub compile { shift->engine->compile(@_) }
sub assemble { shift->assembler->assemble(@_) }
sub load {
    require Carp;
    Carp::confess($_[0] . "->compile() not declared");
}

1;

__END__

=head1 NAME

Text::Xslate::Loader - Loader Base Class

=head1 DESCRIPTION

Text::Xslate::Loader is a base class for Loader classes, but it doesn't do
much by itself. You are also NOT REQUIRED to inherit from this class to make
your own Loader: You just need to provide a "load()" method for it to work.
This class is here because there are a few initialization-related methods
that are mostly common for Loaders.

=head1 CREATING YOUR LOADER

Text::Xslate by default takes a class name as loader and instantiates it
but if you are building a new loader we recommend you don't rely on this
feature.

Instead, instantiate an object yourself and pass it to Text::Xslate:

    Text::Xslate->new(
        loader => MyAwesome::Loader->new()
    );

Your Loader class may need some configuration using the main Text::Xslate
object instance. For that, provide a method named C<configure()>:

    sub configure {
        my ($loader, $engine) = @_;
        # Make whatever necessary change to $loader using $engine
    }

=cut
