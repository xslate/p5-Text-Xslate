package Text::Xslate::Runner;
use Any::Moose;
use Any::Moose '::Util::TypeConstraints';

use File::Spec     ();
use File::Basename ();
use Encode         ();

with any_moose 'X::Getopt';

my $getopt_traits = [any_moose('X::Getopt::Meta::Attribute::Trait')];

has cache_dir => (
    documentation => 'Directory the cache files will be saved in',
    cmd_aliases   => [qw(c)],
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_cache_dir',
    traits        => $getopt_traits,
);

has cache => (
    documentation => 'Cache level',
    cmd_aliases   => [qw(a)],
    is            => 'ro',
    isa           => 'Int',
    predicate     => 'has_cache',
    traits        => $getopt_traits,
);

has module => (
    documentation => 'Modules templates will use (e.g. name=sub1,sub2)',
    cmd_aliases   => [qw(M)],
    is            => 'ro',
    isa           => 'HashRef[Str]',
    predicate     => 'has_module',
    traits        => $getopt_traits,
);

has input_encoding => (
    documentation => 'Input encoding (default: UTF-8)',
    cmd_aliases   => [qw(ie)],
    is            => 'rw',
    isa           => 'Str',
    default       => 'UTF-8',
    predicate     => 'has_input_encoding',
    traits        => $getopt_traits,
);

has output_encoding => (
    documentation => 'Output encoding (default: UTF-8)',
    cmd_aliases   => [qw(oe)],
    is            => 'rw',
    isa           => 'Str',
    default       => 'UTF-8',
    predicate     => 'has_output_encoding',
    traits        => $getopt_traits,
);


has path => (
    documentation => 'Include paths',
    cmd_aliases   => [qw(I)],
    is            => 'ro',
    isa           => 'ArrayRef[Str]',
    predicate     => 'has_path',
    traits        => $getopt_traits,
);

has syntax => (
    documentation => 'Template syntax (e.g. TTerse)',
    cmd_aliases   => [qw(s)],
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_syntax',
    traits        => $getopt_traits,
);

has type => (
    documentation => 'Output content type (html | xml | text)',
    cmd_aliases   => [qw(t)],
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_type',
    traits        => $getopt_traits,
);

has verbose => (
    documentation => 'Warning level (default: 2)',
    cmd_aliases   => [qw(w)],
    is            => 'ro',
    isa           => 'Str',
    default       => 2,
    predicate     => 'has_verbose',
    traits        => $getopt_traits,
);

# --ignore=pattern
any_moose('X::Getopt::OptionTypeMap')->add_option_type_to_map(
    RegexpRef => '=s'
);
coerce 'RegexpRef' => from 'Str' => via { qr/$_/ };
has ignore => (
    documentation => 'Regular expression the process will ignore',
    cmd_aliases   => [qw(i)],
    is            => 'ro',
    isa           => 'RegexpRef',
    coerce        => 1,
    traits        => $getopt_traits,
);

# --suffix old=new
has suffix => (
    documentation => 'Output suffix mapping (e.g. tx=html)',
    cmd_aliases   => [qw(x)],
    is            => 'ro',
    isa           => 'HashRef',
    default       => sub { +{} },
    traits        => $getopt_traits,
);

has dest => (
    documentation => 'Destination directry',
    cmd_aliases   => [qw(o)],
    is            => 'ro',
    isa           => 'Str', # Maybe[Str]
    required      => 0,
    traits        => $getopt_traits,
);

has define => (
    documentation => 'Define template variables (e.g. foo=bar)',
    cmd_aliases   => [qw(D)],
    is            => 'ro',
    isa           => 'HashRef',
    predicate     => 'has_define',
    traits        => $getopt_traits,
);

has eval => (
    documentation => 'One line of template code',
    cmd_aliases   => [qw(e)],
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_eval',
    traits        => $getopt_traits,
);

has engine => (
    documentation => 'Template engine',
    cmd_aliases   => [qw(E)],
    is            => 'ro',
    isa           => 'Str',
    default       => 'Text::Xslate',
    traits        => $getopt_traits,
);

has debug => (
    documentation => 'Debugging flags',
    cmd_aliases   => ['d'],
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_debug',
    traits        => $getopt_traits,
);

has version => (
    documentation => 'Print version information',
    is            => 'ro',
    isa           => 'Bool',
);

sub run {
    my($self, @targets) = @_;

    my %args;
    foreach my $field qw(
        cache_dir cache path syntax
        type verbose
            ) {
        my $method = "has_$field";
        $args{ $field } = $self->$field if $self->$method;
    }
    if($self->has_module) { # re-mapping
        my $mod = $self->module;
        my @mods;
        while(my $name = each %{$mod}) {
            push @mods, $name, [ split /,/, $mod->{$name} ];
        }
        $args{module} = \@mods;
    }

    if(my $ie = $self->input_encoding) {
        $args{input_layer} = ":encoding($ie)";
    }

    local $ENV{XSLATE} = $self->debug
        if $self->has_debug;

    require Text::Xslate;

    if($self->version) {
        print $self->version_info(), "\n";
        return;
    }

    Any::Moose::load_class($self->engine);
    my $xslate = $self->engine->new(%args);

    if($self->has_eval) {
        my %vars;
        if($self->has_define){
            %vars = %{$self->define};
        }
        $vars{ARGV} = \@targets;
        $vars{ENV}  = \%ENV;
        print $xslate->render_string($self->eval, \%vars), "\n";
        return;
    }

    foreach my $target (@targets) {
        # XXX if you have a directory, just pushed that into the list of
        # path in the xslate object
        if ( -d $target ) {
            local $self->{__process_base} = scalar(File::Spec->splitdir($target));
            local $xslate->{path} = [ $target, @{ $xslate->{path} || [] } ];
            $self->process_tree( $xslate, $target );
        } else {
            my $dirname = File::Basename::dirname($target);
            local $self->{__process_base} = scalar(File::Spec->splitdir($dirname));
            local $xslate->{path} = [ $dirname, @{ $xslate->{path} || [] } ];
            $self->process_file( $xslate, $target );
        }
    }
}

sub process_tree {
    my ($self, $xslate, $dir) = @_;

    opendir( my $fh, $dir ) or die "XXX";

    while (my $e = readdir $fh) {
        next if $e =~ /^\.+$/;
        my $target = File::Spec->catfile( $dir, $e );
        if (-d $target) {
            $self->process_tree( $xslate, $target );
        } else {
            $self->process_file( $xslate, $target );
        }
    }
}

sub process_file {
    my ($self, $xslate, $file) = @_;

    if ( my $ignore = $self->ignore ) {
        if ($file =~ $ignore) {
            return;
        }
    }

    my $suffix_map = $self->suffix;
    my $dest = $self->dest;

    my ($suffix) = ($file =~ /\.([^\.]+)$/);

    my $filearg = $file;
    if (my $base = $self->{__process_base}) {
        my @comps = File::Spec->splitdir( File::Basename::dirname($file) );
        splice @comps, 0, $base;
        $filearg = File::Spec->catfile( @comps, File::Basename::basename($file) );
    }

    my $outfile;

    if(defined $dest or exists $suffix_map->{$suffix}) {
        $outfile= File::Spec->catfile( $dest, $filearg );
        if (my $replace = $suffix_map->{ $suffix }) {
            $outfile =~ s/$suffix$/$replace/;
        }

        my $dir = File::Basename::dirname( $outfile );
        if (! -d $dir) {
            require File::Path;
            if (! File::Path::mkpath( $dir )) {
                die "Could not create directory $dir: $!";
            }
        }
    }

    my $rendered = $xslate->render( $filearg, $self->define );
    $rendered = Encode::encode($self->output_encoding, $rendered);

    if(defined $outfile) {
        my $fh;
        open( $fh, '>', $outfile )
            or die "Could not open file $outfile for writing: $!";

        print $fh $rendered;

        close $fh or warn "Could not close file $outfile: $!";
    }
    else {
        print $rendered;
    }
}

sub version_info {
    my($self) = @_;
    return sprintf q{%s (%s) on Text::Xslate/%s, Perl/%vd.},
        $0, ref($self),
        Text::Xslate->VERSION,
        $^V,
    ;
}

no Any::Moose;
no Any::Moose '::Util::TypeConstraints';
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::Runner - The guts of the xslate(1) command

=head1 DESCRIPTION

This is the guts of C<xslate(1)>.

=head1 AUTHOR

Maki, Daisuke (lestrrat)

Fuji, Goro (gfx)

=head1 SEE ALSO

L<Text::Xslate>

L<xslate(1)>

=cut

