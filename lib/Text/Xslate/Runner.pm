package Text::Xslate::Runner;
use Mouse;
use Mouse::Util::TypeConstraints;

use List::Util     ();
use File::Spec     ();
use File::Basename ();
use Getopt::Long   ();

{
    package
        Text::Xslate::Runner::Getopt;
    use Mouse::Role;

    has cmd_aliases => (
        is         => 'ro',
        isa        => 'ArrayRef[Str]',
        default    => sub { [] },
        auto_deref => 1,
    );

    no Mouse::Role;
}

my $getopt = Getopt::Long::Parser->new(
    config => [qw(
        no_ignore_case
        bundling
        no_auto_abbrev
    )],
);

my $Pattern = subtype __PACKAGE__ . '.Pattern', as 'RegexpRef';
coerce $Pattern => from 'Str' => via { qr/$_/ };

my $getopt_traits = ['Text::Xslate::Runner::Getopt'];

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
has ignore => (
    documentation => 'Regular expression the process will ignore',
    cmd_aliases   => [qw(i)],
    is            => 'ro',
    isa           => $Pattern,
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
    documentation => 'Destination directory',
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
    traits        => $getopt_traits,
);

has help => (
    documentation => 'Print this help',
    is            => 'ro',
    isa           => 'Bool',
    traits        => $getopt_traits,
);

has targets => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]',
    default    => sub { [] },
    auto_deref => 1,
);

my @Spec = __PACKAGE__->_build_getopt_spec();
sub getopt_spec { @Spec }

sub _build_getopt_spec {
    my($self) = @_;

    my @spec;
    foreach my $attr($self->meta->get_all_attributes) {
        next unless $attr->does('Text::Xslate::Runner::Getopt');

        my $isa = $attr->type_constraint;

        my $type;
        if($isa->is_a_type_of('Bool')) {
            $type = '';
        }
        elsif($isa->is_a_type_of('Int')) {
            $type = '=i';
        }
        elsif($isa->is_a_type_of('Num')) {
            $type = '=f';
        }
        elsif($isa->is_a_type_of('ArrayRef')) {
            $type = '=s@';
        }
        elsif($isa->is_a_type_of('HashRef')) {
            $type = '=s%';
        }
        else {
            $type = '=s';
        }

        my @names = ($attr->name, $attr->cmd_aliases);
        push @spec, join('|', @names) . $type;
    }
    return @spec;
}

sub new_from {
    my $class = shift;
    local @ARGV = @_;
    my %opts;
    $getopt->getoptions(\%opts, $class->getopt_spec())
        or die $class->help_message;

    $opts{targets} = [@ARGV];
    return $class->new(\%opts);
}

sub run {
    my($self, @targets) = @_;

    my %args;
    foreach my $field (qw(
        cache_dir cache path syntax
        type verbose
            )) {
        my $method = "has_$field";
        $args{ $field } = $self->$field if $self->$method;
    }
    if($self->has_module) { # re-mapping
        my $mod = $self->module;
        my @mods;
        foreach my $name(keys %{$mod}) {
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

    if($self->help) {
        print $self->help_message();
        return;
    }
    elsif($self->version) {
        print $self->version_info();
        return;
    }

    Mouse::load_class($self->engine);
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

    opendir( my $fh, $dir ) or die "Could not opendir '$dir': !";

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
    $rendered = $self->_encode($rendered);

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
    return sprintf qq{%s (%s) on Text::Xslate/%s, Perl/%vd.\n},
        File::Basename::basename($0), ref($self),
        Text::Xslate->VERSION,
        $^V,
    ;
}

sub help_message {
    my($self) = @_;
    my @options;
    foreach my $attr($self->meta->get_all_attributes) {
        next unless $attr->does('Text::Xslate::Runner::Getopt');

        my $name  = join ' ', map { length($_) == 1 ? "-$_": "--$_" }
                                ($attr->cmd_aliases, $attr->name);

        push @options, [ $name => $attr->documentation ];
    }
    my $max_len = List::Util::max( map { length $_->[0] } @options );

    my $message = sprintf "usage: %s [options...] [input-files]\n",
        File::Basename::basename($0);

    foreach my $opt(@options) {
        $message .= sprintf "    %-*s  %s\n", $max_len, @{$opt};
    }

    $message .= <<'EXAMPLE';

Examples:
    xslate -e "Hello, <: $ARGV[0] :> world!" Kolon
    xslate -s TTerse -e "Hello, [% ARGV.0 %] world!" TTerse

EXAMPLE
    return $message;
}

sub _encode {
    my($self, $str) = @_;
    my $oe = $self->output_encoding;
    if($oe ne 'UTF-8') {
        require Encode;
        return Encode::encode($oe, $str);
    }
    else {
        utf8::encode($str);
        return $str;
    }
}

no Mouse;
no Mouse::Util::TypeConstraints;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Text::Xslate::Runner - The guts of the xslate(1) command

=head1 DESCRIPTION

This is the guts of C<xslate(1)>.

=head1 AUTHOR

This is originally written by Maki, Daisuke (lestrrat),
and also maintained by Fuji, Goro (gfx),

=head1 SEE ALSO

L<Text::Xslate>

L<xslate(1)>

=cut

