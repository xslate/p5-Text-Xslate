package Text::Xslate;
# The Xslate engine class
use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.1008';

use parent qw(Exporter);
our @EXPORT_OK = qw(escaped_string);

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    literal_to_value
);

use constant _DUMP_LOAD_FILE => scalar($DEBUG =~ /\b dump=load_file \b/xms);

use File::Spec;

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

my $XSLATE_MAGIC = ".xslate $VERSION\n";

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    $args{suffix}       //= '.tx';
    $args{path}         //= [ '.' ];
    $args{cache_dir}    //= File::Spec->tmpdir;
    $args{input_layer}  //= ':utf8';
    $args{cache}        //= 1;
    $args{compiler}     //= 'Text::Xslate::Compiler';
    $args{syntax}       //= 'Kolon'; # passed directly to the compiler
   #$args{function}     //= {};      # see _compiler()

    $args{template}       = {};

    if(exists $args{file}) {
        require Carp;
        Carp::carp('"file" option makes no sense. Use render($file, \%vars) directly');
    }

    if(!ref $args{path}) {
        $args{path} = [$args{path}];
    }

    my $self = bless \%args, $class;
    $self->_load_input();
    return $self;
}

sub render;

sub _initialize;

sub _load_input { # for <input>
    my($self) = @_;

    my $source = 0;
    my $protocode;

    if($self->{string}) {
        require Carp;
        Carp::carp('"string" option has been deprecated. Use render_string() instead');
        $source++;
        $protocode = $self->_compiler->compile($self->{string});
    }

    if($self->{protocode}) {
        $source++;
        $protocode = $self->{protocode};
    }

    if($source > 1) {
        $self->throw_error("Multiple template sources are specified");
    }

    if(defined $protocode) {
        $self->_initialize($protocode, undef, undef, undef, undef);
    }

    return $protocode;
}

sub render_string {
    my($self, $str, $vars) = @_;

    # because render_string() is provided for testing,
    # it does not cache compiled code.
    local $self->{cache} = 0;
    my $protocode = $self->_compiler->compile($str);
    $self->_initialize($protocode, undef, undef, undef, undef);
    return $self->render(undef, $vars);
}

sub find_file {
    my($self, $file, $mtime) = @_;

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;
    my $is_compiled;

    foreach my $p(@{$self->{path}}) {
        $fullpath = File::Spec->catfile($p, $file);
        $orig_mtime = (stat($fullpath))[9] // next; # does not exist

        $cachepath = File::Spec->catfile($self->{cache_dir}, $file . 'c');
        # find the cache
        # TODO

        if(-f $cachepath) {
            $cache_mtime = (stat(_))[9]; # compiled

            # mtime indicates the threshold time.
            # see also tx_load_template() in xs/Text-Xslate.xs
            $is_compiled = (($mtime // $cache_mtime) >= $orig_mtime);
            last;
        }
        else {
            $is_compiled = 0;
        }
    }

    if(defined $orig_mtime) {
        return {
            fullpath    => $fullpath,
            cachepath   => $cachepath,

            orig_mtime  => $orig_mtime,
            cache_mtime => $cache_mtime,

            is_compiled => $is_compiled,
        };
    }
    else {
        return undef;
    }
}


sub load_file {
    my($self, $file, $mtime) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;

    if($file eq '<input>') { # simply reload it
        return $self->_load_input()
            // $self->throw_error("LoadError: Template source <input> does not exist");
    }

    my $f = $self->find_file($file, $mtime);

    if(not defined $f) {
        $self->throw_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    my $fullpath    = $f->{fullpath};
    my $cachepath   = $f->{cachepath};
    my $is_compiled = $f->{is_compiled};

    if($self->{cache} == 0) {
        $is_compiled = 0;
    }

    print STDOUT "---> $fullpath ($is_compiled)\n" if _DUMP_LOAD_FILE;

    my $string;
    {
        my $to_read = $is_compiled ? $cachepath : $fullpath;
        open my($in), '<' . $self->{input_layer}, $to_read
            or $self->throw_error("LoadError: Cannot open $to_read for reading: $!");

        if($is_compiled && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $cachepath
                or $self->throw_error("LoadError: Cannot unlink $cachepath: $!");
            goto &load_file; # retry
        }

        local $/;
        $string = <$in>;
    }

    my $protocode;
    if($is_compiled) {
        $protocode = $self->_load_assembly($string);
    }
    else {
        $protocode = $self->_compiler->compile($string, file => $file);

        if($self->{cache}) {
            require File::Basename;

            my $cachedir = File::Basename::dirname($cachepath);
            if(not -e $cachedir) {
                require File::Path;
                File::Path::mkpath($cachedir);
            }
            open my($out), '>:raw:utf8', $cachepath
                or $self->throw_error("LoadError: Cannot open $cachepath for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $cachepath;
            }
            else {
                $is_compiled = 1;
            }
        }
    }
    # if $mtime is undef, the runtime does not check freshness of caches.
    my $cache_mtime;
    if($self->{cache} < 2) {
        if($is_compiled) {
            $cache_mtime = $f->{cache_mtime} // ( stat $cachepath )[9];
        }
        else {
            $cache_mtime = 0; # no compiled cache, always need to reload
        }
    }

    $self->_initialize($protocode, $file, $fullpath, $cachepath, $cache_mtime);
    return $protocode;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        require Mouse::Util;
        $compiler = Mouse::Util::load_class($compiler)->new(
            engine => $self,
            syntax => $self->{syntax},
        );

        if(my $funcs = $self->{function}) {
            $compiler->define_function(keys %{$funcs});
        }

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub _load_assembly {
    my($self, $assembly) = @_;

    my @protocode;
    while($assembly =~ m{
            ^[ \t]*
                ($IDENT)                        # an opname
                (?: [ \t]+ ($STRING|$NUMBER) )? # an operand
                (?:\#($NUMBER))?                # line number
                [^\n]*                          # any comments
            \n}xmsog) {

        my $name  = $1;
        my $value = $2;
        my $line  = $3;

        push @protocode, [ $name, literal_to_value($value), $line ];
    }

    return \@protocode;
}

sub throw_error {
    shift;
    unshift @_, 'Xslate: ';
    require Carp;
    goto &Carp::croak;
}

sub dump :method {
    my($self) = @_;
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self], ['xslate']);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    $dd->Useqq(1);
    return $dd->Dump();
}

1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.1008.

=head1 SYNOPSIS

    use Text::Xslate;
    use FindBin qw($Bin);

    my $tx = Text::Xslate->new(
        # the fillowing options are optional.
        path       => ['.'],
        cache_path => File::Spec->tmpdir,
        cache      => 1,
    );

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            { title => 'River out of Eden'     },
            { title => 'Beautiful code'        },
        ],
    );

    # for files
    print $tx->render('hello.tx', \%vars);

    # for strings
    my $template = q{
        <h1><: $title :></h1>
        <ul>
        : for $books ->($book) {
            <li><: $book.title :></li>
        : } # for
        </ul>
    };

    print $tx->render_string($template, \%vars);

    # you can tell the engine that some strings are already escaped.
    use Text::Xslate qw(escaped_string);

    $vars{email} = escaped_string('gfx &lt;gfuji at cpan.org&gt;');
    # or
    $vars{email} = Text::Xslate::EscapedString->new(
        'gfx &lt;gfuji at cpan.org&gt;',
    ); # if you don't want to pollute your namespace.


    # if you want Template-Toolkit syntx:
    $tx = Text::Xslate->new(syntax => 'TTerse');
    # ...

=head1 DESCRIPTION

B<Text::Xslate> is a template engine tuned for persistent applications.
This engine introduces the virtual machine paradigm. That is, templates are
compiled into xslate opcodes, and then executed by the xslate virtual machine
just like as Perl does.

B<This software is under development>.
Version 0.1xxx is a developing stage, which may include radical changes.
Version 0.2xxx and more will be somewhat stable.

=head2 Features

=head3 High performance

Xslate has an virtual machine written in XS, which is highly optimized.
According to benchmarks, Xslate is B<2-10> times faster than other template
engines (Template-Toolkit, HTML::Template::Pro, Text::MicroTemplate, etc).

=head3 Template cascading

Xslate supports template cascading, which allows one to extend
templates with block modifiers.

This mechanism is also called as template inheritance.

=head3 Syntax alternation

The Xslate engine and parser/compiler are completely separated so that
one can use alternative parsers.

Currently, C<TTerse>, a Template-Toolkit-like parser, is supported as an
alternative.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) :XslateEngine >>

Creates a new xslate template engine.

Possible options ares:

=over

=item C<< path => \@path // ["."] >>

Specifies the include paths.

=item C<< function => \%functions >>

Specifies functions.

Functions may be called as C<f($arg)> or C<$arg | f>.

=item C<< cache => $level // 1 >>

Sets the cache level.

If I<$level> == 1 (default), Xslate caches compiled templates on the disk, and
checks the freshness of the original templates every time.

If I<$level> E<gt>= 2, caches will be created but the freshness
will not be checked.

I<$level> == 0 creates no caches. It's provided for testing.

=item C<< cache_dir => $dir // File::Spec->tmpdir >>

Specifies the directry used for caches.

=item C<< input_layer => $perliolayers // ":utf8" >>

Specifies PerlIO layers for reading templates.

=item C<< syntax => $moniker >>

Specifies the template syntax.

If I<$moniker> is undefined, the default parser will be used.

=back

=head3 B<< $tx->render($file, \%vars) :Str >>

Renders a template file with variables, and returns the result.

Note that I<$file> may be cached according to the cache level.

=head3 B<< $tx->render_string($string, \%vars) :Str >>

Renders a template string with variables, and returns the result.

Note that I<$string> is never cached so that this method is suitable for testing.

=head3 B<< $tx->load_file($file) :Void >>

Loads I<$file> for following C<render($file, \%vars)>. Compiles and caches it
if needed.

This method may be used for pre-compiling template files.

=head3 Exportable functions

=head3 C<< escaped_string($str :Str) -> EscapedString >>

Marks I<$str> as escaped. Escaped strings will not be escaped by the engine,
so you have to escape these strings.

For example:

    my $tx   = Text::Xslate->new();
    my $tmpl = 'Mailaddress: <: $email :>';
    my %vars = (
        email => "Foo &lt;foo@example.com&gt;",
    );
    print $tx->render_string($tmpl, \%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

=head1 TEMPLATE SYNTAX

There are syntaxes you can use:

=over

=item Kolon

B<Kolon> is the default syntax, using C<< <: ... :> >> tags and
C<< : ... >> line code, which is explained in L<Text::Xslate::Syntax::Kolon>.

=item Metakolon

B<Metakolon> is the same as Kolon except for using C<< [% ... %] >> tags and
C<< % ... >> line code, instead of C<< <: ... :> >> and C<< : ... >>.

=item TTerse

B<TTerse> is a syntax that is a subset of Template-Toolkit 2,
which is explained in L<Text::Xslate::Syntax::TTerse>.

=back

=head1 NOTES

In Xslate templates, you cannot use C<undef> as a valid value.
The use of C<undef> will cause fatal errors as if
C<use warnings FALTAL => "all"> was specified.
However, unlike Perl, you can use equal operators to check whether
the value is defined or not:

    : if $value == nil { ; }
    : if $value != nil { ; }

    [% # on TTerse syntax -%]
    [% IF $value == nil %] [% END %]
    [% IF $value != nil %] [% END %]

Or, you can also use defined-or operator (//):

    : # on Kolon syntax
    Hello, <: $value // "Xslate" :> world!

    [% # on TTerse syntax %]
    Hello, [% $value // "Xslate" %] world!


=head1 DEPENDENCIES

Perl 5.10.0 or later, and a C compiler.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.  Patches are welcome :)

=head1 SEE ALSO

Xslate template syntaxes:

L<Text::Xslate::Syntax::Kolon>

L<Text::Xslate::Syntax::Metakolon>

L<Text::Xslate::Syntax::TTerse>

Other template modules:

L<Text::MicroTemplate>

L<Text::MicroTemplate::Extended>

L<Text::ClearSilver>

L<Template-Toolkit>

L<HTML::Template>

L<HTML::Template::Pro>

Benchmarks:

L<Template::Benchmark>

=head1 ACKNOWLEDGEMENTS

Thanks to lestrrat for the suggestion to the interface of C<render()>.

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug-finding.

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
