package Text::Xslate;
# The Xslate engine class
use 5.008_001;
use strict;
use warnings;

use Carp              ();
use File::Spec        ();
use Data::MessagePack ();
use Scalar::Util      ();

our ($VERSION, @ISA, @EXPORT_OK);

use Text::Xslate::Constants();
use XSLoader;
BEGIN {
    $VERSION = '3.1.0';

    # all the exportable functions are defined in ::Util
    @EXPORT_OK = qw(
        mark_raw
        unmark_raw
        escaped_string
        html_escape
        uri_escape
        html_builder
    );

    XSLoader::load(__PACKAGE__, $VERSION);

    @ISA = qw(Text::Xslate::Engine);
}
use Text::Xslate::Util @EXPORT_OK;

sub USE_XS { 1 } # deprecated.

# for error messages (see T::X::Util)
sub input_layer { ref($_[0]) ? $_[0]->{input_layer} : ':utf8' }

package Text::Xslate::Engine; # base class
use Mouse;
use File::Spec;
use Text::Xslate::Constants qw(DUMP_LOAD DEFAULT_CACHE_DIR);
use Text::Xslate::Assembler;
use Text::Xslate::Util qw(
    dump
);

extends 'Exporter';

with 'Text::Xslate::MakeError';

# the real defaults are defined in the parser
my %parser_option = (
    line_start => undef,
    tag_start  => undef,
    tag_end    => undef,
);

# the real defaults are defined in the compiler
my %compiler_option = (
    syntax     => undef,
    type       => undef,
    header     => undef, # template augment
    footer     => undef, # template augment
    macro      => undef, # template augment
);

my %builtin = (
    html_escape  => \&Text::Xslate::Util::html_escape,
    mark_raw     => \&Text::Xslate::Util::mark_raw,
    unmark_raw   => \&Text::Xslate::Util::unmark_raw,
    uri_escape   => \&Text::Xslate::Util::uri_escape,

    is_array_ref => \&Text::Xslate::Util::is_array_ref,
    is_hash_ref  => \&Text::Xslate::Util::is_hash_ref,

    dump         => \&Text::Xslate::Util::dump,

    # aliases
    raw          => 'mark_raw',
    html         => 'html_escape',
    uri          => 'uri_escape',
);

sub bytecode_version { 2 };

sub default_functions { +{} } # overridable

sub parser_option { # overridable
    return \%parser_option;
}

sub compiler_option { # overridable
    return \%compiler_option;
}

sub replace_option_value_for_magic_token { # overridable
    #my($self, $name, $value) = @_;
    #$value;
    return $_[2];
}

has magic_template => (
    is => 'ro',
    lazy => 1,
    builder => 'build_magic_template',
);

sub build_magic_template {
    my $self = shift;
    # You need to add some instance specific magic
    my @options = (
        ref($self->{compiler}) || $self->{compiler},
        $self->_filter_options_for_magic_token($self->_extract_options($self->parser_option)),
        $self->_filter_options_for_magic_token($self->_extract_options($self->compiler_option)),
        $self->input_layer,
        [sort keys %{ $self->{function} }],
    );
    # $bytecode_version + $fullpath + $compiler_and_parser_options
    return sprintf qq{xslate;%s;%%s;%s;},
        $self->bytecode_version(),
        Data::MessagePack->pack([@options])
}

sub options { # overridable
    my($self) = @_;
    return {
        # name       => default
        suffix       => '.tx',
        path         => ['.'],
        input_layer  => $self->input_layer,
        cache        => 1, # 0: not cached, 1: checks mtime, 2: always cached
        cache_dir    => DEFAULT_CACHE_DIR,
        module       => undef,
        function     => undef,
        html_builder_module => undef,
        compiler     => 'Text::Xslate::Compiler',
        loader       => 'Text::Xslate::Loader::File',
        assembler    => 'Text::Xslate::Assembler',

        verbose      => 1,
        warn_handler => undef,
        die_handler  => undef,
        pre_process_handler => undef,

        %{ $self->parser_option },
        %{ $self->compiler_option },
    };
}

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    my $options = $class->options;
    my $used    = 0;
    my $nargs   = scalar keys %args;
    foreach my $key(keys %{$options}) {
        if(exists $args{$key}) {
            $used++;
        }
        elsif(defined($options->{$key})) {
            $args{$key} = $options->{$key};
        }
    }

    if($used != $nargs) {
        my @unknowns = sort grep { !exists $options->{$_} } keys %args;
        warnings::warnif(misc
            => "$class: Unknown option(s): " . join ' ', @unknowns);
    }

    $args{path} = [
        map { ref($_) ? $_ : File::Spec->rel2abs($_) }
            ref($args{path}) eq 'ARRAY' ? @{$args{path}} : $args{path}
    ];

    my $arg_function= $args{function};

    my %funcs;
    $args{function} = \%funcs;

    $args{template} = {}; # template structures

    my $self = bless \%args, $class;

    # definition of functions and methods

    # builtin functions
    %funcs = %builtin;
    $self->_register_builtin_methods(\%funcs);

    # per-class functions
    $self->_merge_hash(\%funcs, $class->default_functions());

    # user-defined functions
    if(defined $args{module}) {
        $self->_merge_hash(\%funcs,
            Text::Xslate::Util::import_from(@{$args{module}}));
    }

    # user-defined html builder functions
    if(defined $args{html_builder_module}) {
        my $raw = Text::Xslate::Util::import_from(@{$args{html_builder_module}});
        my $html_builders = +{
            map {
                ($_ => &Text::Xslate::Util::html_builder($raw->{$_}))
            } keys %$raw
        };
        $self->_merge_hash(\%funcs, $html_builders);
    }

    $self->_merge_hash(\%funcs, $arg_function);

    $self->_resolve_function_aliases(\%funcs);

    $self->_setup_components();
    return $self;
}

sub _merge_hash {
    my($self, $base, $add) = @_;
    foreach my $name(keys %{$add}) {
        $base->{$name} = $add->{$name};
    }
    return;
}

sub _resolve_function_aliases {
    my($self, $funcs) = @_;

    foreach my $f(values %{$funcs}) {
        my %seen; # to avoid infinite loops
        while(!( ref($f) or Scalar::Util::looks_like_number($f) )) {
            my $v = $funcs->{$f} or $self->throw_error(
               "Cannot resolve a function alias '$f',"
               . " which refers nothing",
            );

            if( ref($v) or Scalar::Util::looks_like_number($v) ) {
                $f = $v;
                last;
            }
            else {
                $seen{$v}++ and $self->throw_error(
                    "Cannot resolve a function alias '$f',"
                    . " which makes circular references",
                );
            }
        }
    }

    return;
}

sub load_string { # called in render_string()
    my($self, $string) = @_;
    if(not defined $string) {
        $self->throw_error("LoadError: Template string is not given");
    }
    $self->note('  _load_string: %s', join '\n', split /\n/, $string)
        if DUMP_LOAD;
    $self->{string_buffer} = $string;
    my $asm = $self->compile($string);
    $self->_assembler->assemble($asm, '<string>', \$string, undef, undef);
    return $asm;
}

sub find_file {
    my ($self, $file) = @_;
    $self->_loader->locate_file($file);
}

# XXX To be deprecated ?
# The interface is too specific for file-based templates
sub load_file {
    my($self, $file, $mtime, $omit_augment) = @_;
    local $self->{omit_augment} = $omit_augment;
    my $loader = $self->_loader;
    my $asm = $loader->load($file, $mtime);
    return $asm;
}

sub slurp_template {
    my($self, $input_layer, $fullpath) = @_;

    if (DUMP_LOAD) {
$self->note("slurp_template: input_layer(%s), fullpath(%s)\n",
$input_layer, $fullpath);
    }

    if (ref $fullpath eq 'SCALAR') {
        return $$fullpath;
    } else {
        open my($source), '<' . $input_layer, $fullpath
            or $self->throw_error("LoadError: Cannot open $fullpath for reading: $!");
        local $/;
        return scalar <$source>;
    }
}

sub _digest {
    my($self, $content) = @_;
    require 'Digest/MD5.pm'; # we don't want to create its namespace
    my $md5 = Digest::MD5->new();
    utf8::encode($content);
    $md5->add($content);
    return $md5->hexdigest();
}

sub _extract_options {
    my($self, $opt_ref) = @_;
    my @options;
    foreach my $name(sort keys %{$opt_ref}) {
        if(exists $self->{$name}) {
            push @options, $name => $self->{$name};
        }
    }
    return @options;
}

sub _filter_options_for_magic_token {
    my($self, @options) = @_;
    my @filterd_options;
    while (@options) {
        my $name  = shift @options;
        my $value = $self->replace_option_value_for_magic_token($name, shift @options);
        push(@filterd_options, $name => $value);
    }
    @filterd_options;
}

sub _setup_components {
    my $self = shift;

    # MUST BE IN THIS ORDER, b.c. loader uses assembler
    foreach my $name (qw(assembler loader)) {
        my $component = $self->{$name};
        if (ref $component) {
            $component->configure($self);
        } else {
            require Mouse;
            Mouse::load_class($component);
            $component = $component->build($self);
        }
        $self->{$name} = $component;
    }
}

sub _loader { $_[0]->{loader} }
sub _assembler { $_[0]->{assembler} }
sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        Mouse::load_class($compiler);

        my $input_layer = $self->input_layer;
        $compiler = $compiler->new(
            engine      => $self,
            input_layer => $input_layer,
            $self->_extract_options($self->compiler_option),
            parser_option => {
                input_layer => $input_layer,
                $self->_extract_options($self->parser_option),
            },
        );

        $compiler->define_function(keys %{ $self->{function} });

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub compile {
    my $self = shift;
    return $self->_compiler->compile(@_,
        omit_augment => $self->{omit_augment});
}

sub _magic_token_arguments {
    my $self = shift;
    return (
    );
}

sub note {
    my($self, @args) = @_;
    printf STDERR @args;
}

package Text::Xslate;
1;
__END__

=head1 NAME

Text::Xslate - Scalable template engine for Perl5

=head1 VERSION

This document describes Text::Xslate version 3.1.0.

=head1 SYNOPSIS

    use Text::Xslate qw(mark_raw);

    my $tx = Text::Xslate->new();

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            # ...
        ],

        # mark HTML components as raw not to escape its HTML tags
        gadget => mark_raw('<div class="gadget">...</div>'),
    );

    # for files
    print $tx->render('hello.tx', \%vars);

    # for strings (easy but slow)
    my $template = q{
        <h1><: $title :></h1>
        <ul>
        : for $books -> $book {
            <li><: $book.title :></li>
        : } # for
        </ul>
    };

    print $tx->render_string($template, \%vars);

=head1 DESCRIPTION

B<Xslate> is a template engine, tuned for persistent applications,
safe as an HTML generator, and with rich features.

There are a lot of template engines in CPAN, for example Template-Toolkit,
Text::MicroTemplate, HTML::Template, and so on, but all of them have
some weak points: a full-featured template engine may be slow,
while a fast template engine may be too simple to use. This is why Xslate is
developed, which is the best template engine for web applications.

The concept of Xslate is strongly influenced by Text::MicroTemplate
and Template-Toolkit 2, but the central philosophy of Xslate is different
from them. That is, the philosophy is B<sandboxing> that the template logic
should not have no access outside the template beyond your permission.

Other remarkable features are as follows:

=head2 Features

=head3 High performance

This engine introduces the virtual machine paradigm. Templates are
compiled into intermediate code, and then executed by the virtual machine,
which is highly optimized for rendering templates. Thus, Xslate is
much faster than any other template engines.

The template roundup project by Sam Graham shows Text::Xslate got
amazingly high scores in I<instance_reuse> condition
(i.e. for persistent applications).

=over

=item The template roundup project

L<http://illusori.co.uk/projects/Template-Roundup/>

=item Perl Template Roundup October 2010 Performance vs Variant Report: instance_reuse

L<http://illusori.co.uk/projects/Template-Roundup/201010/performance_vs_variant_by_feature_for_instance_reuse.html>

=back

There are also benchmarks in F<benchmark/> directory in the Xslate distribution.

=head3 Smart escaping for HTML metacharacters

Xslate employs the B<smart escaping strategy>, where a template engine
escapes all the HTML metacharacters in template expressions unless users
mark values as B<raw>.
That is, the output is unlikely to prone to XSS.

=head3 Template cascading

Xslate supports the B<template cascading>, which allows you to extend
templates with block modifiers. It is like a traditional template inclusion,
but is more powerful.

This mechanism is also called as template inheritance.

=head3 Easiness to enhance

Xslate is ready to enhance. You can add functions and methods to the template
engine and even add a new syntax via extending the parser.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) >>

Creates a new Xslate template engine with options. You can reuse the instance
for multiple call of C<render()>.

Possible options are:

=over

=item C<< path => \@path // ['.'] >>

Specifies the include paths, which may be directory names or virtual paths,
i.e. HASH references which contain C<< $file_name => $content >> pairs.

Note that if you use taint mode (C<-T>), you have to give absolute paths
to C<path> and C<cache_dir>. Otherwise you'll get errors because they
depend on the current working directory which might not be secure.

=item C<< cache => $level // 1 >>

Sets the cache level.

If C<< $level == 1 >> (default), Xslate caches compiled templates on the disk, and
checks the freshness of the original templates every time.

If C<< $level >= 2 >>, caches will be created but the freshness
will not be checked.

C<< $level == 0 >> uses no caches, which is provided for testing.

=item C<< cache_dir => $dir // "$ENV{HOME}/.xslate_cache" >>

Specifies the directory used for caches. If C<$ENV{HOME}> doesn't exist,
C<< File::Spec->tmpdir >> will be used.

You B<should> specify this option for productions to avoid conflicts of
template names.

=item C<< function => \%functions >>

Specifies a function map which contains name-coderef pairs.
A function C<f> may be called as C<f($arg)> or C<$arg | f> in templates.

Note that those registered function have to return a B<text string>,
not a binary string unless you want to handle bytes in whole templates.
Make sure what you want to use returns whether text string or binary
strings.

For example, some methods of C<Time::Piece> might return a binary string
which is encoded in UTF-8, so you'd like to decode their values.

    # under LANG=ja_JP.UTF-8 on MacOSX (Darwin 11.2.0)
    use Time::Piece;
    use Encode qw(decode);

    sub ctime {
        my $ctime = Time::Piece->new->strftime; # UTF-8 encoded bytes
        return decode "UTF-8", $ctime;
    }

    my $tx = Text::Xslate->new(
        function => {
            ctime => \&ctime,
        },
        ...,
    );

Built-in functions are described in L<Text::Xslate::Manual::Builtin>.

=item C<< module => [$module => ?\@import_args, ...] >>

Imports functions from I<$module>, which may be a function-based or bridge module.
Optional I<@import_args> are passed to C<import> as C<< $module->import(@import_args) >>.

For example:

    # for function-based modules
    my $tx = Text::Xslate->new(
        module => ['Digest::SHA1' => [qw(sha1_hex)]],
    );
    print $tx->render_string(
        '<: sha1_hex($x).substr(0, 6) :>',
        { x => foo() },
    ); # => 0beec7

    # for bridge modules
    my $tx = Text::Xslate->new(
        module => ['Text::Xslate::Bridge::Star'],
    );
    print $tx->render_string(
        '<: $x.uc() :>',
        { x => 'foo' },
    ); # => 'FOO'

Because you can use function-based modules with the C<module> option, and
also can invoke any object methods in templates, Xslate doesn't require
specific namespaces for plugins.

=item C<< html_builder_module => [$module => ?\@import_args, ...] >>

Imports functions from I<$module>, wrapping each function with C<html_builder()>.

=item C<< input_layer => $perliolayers // ':utf8' >>

Specifies PerlIO layers to open template files.

=item C<< verbose => $level // 1 >>

Specifies the verbose level.

If C<< $level == 0 >>, all the possible errors will be ignored.

If C<< $level >= 1 >> (default), trivial errors (e.g. to print nil) will be ignored,
but severe errors (e.g. for a method to throw the error) will be warned.

If C<< $level >= 2 >>, all the possible errors will be warned.

=item C<< suffix => $ext // '.tx' >>

Specify the template suffix, which is used for C<cascade> and C<include>
in Kolon.

Note that this is used for static name resolution. That is, the compiler
uses it but the runtime engine doesn't.

=item C<< syntax => $name // 'Kolon' >>

Specifies the template syntax you want to use.

I<$name> may be a short name (e.g. C<Kolon>), or a fully qualified name
(e.g. C<Text::Xslate::Syntax::Kolon>).

This option is passed to the compiler directly.

=item C<< type => $type // 'html' >>

Specifies the output content type. If I<$type> is C<html> or C<xml>,
smart escaping is applied to template expressions. That is,
they are interpolated via the C<html_escape> filter.
If I<$type> is C<text> smart escaping is not applied so that it is
suitable for plain texts like e-mails.

I<$type> may be B<html>, B<xml> (identical to C<html>), and B<text>.

This option is passed to the compiler directly.

=item C<< line_start => $token // $parser_defined_str >>

Specify the token to start line code as a string, which C<quotemeta> will be applied to. If you give C<undef>, the line code style is disabled.

This option is passed to the parser via the compiler.

=item C<< tag_start => $str // $parser_defined_str >>

Specify the token to start inline code as a string, which C<quotemeta> will be applied to.

This option is passed to the parser via the compiler.

=item C<< tag_end => $str // $parser_defined_str >>

Specify the token to end inline code as a string, which C<quotemeta> will be applied to.

This option is passed to the parser via the compiler.

=item C<< header => \@template_files >>

Specify the header template files, which are inserted to the head of each template.

This option is passed to the compiler.

=item C<< footer => \@template_files >>

Specify the footer template files, which are inserted to the foot of each template.

This option is passed to the compiler.

=item C<< warn_handler => \&cb >>

Specify the callback I<&cb> which is called on warnings.

=item C<< die_handler => \&cb >>

Specify the callback I<&cb> which is called on fatal errors.

=item C<< pre_process_handler => \&cb >>

Specify the callback I<&cb> which is called after templates are loaded from the disk
in order to pre-process template.

For example:

    # Remove withespace from templates
    my $tx = Text::Xslate->new(
        pre_process_handler => sub {
            my $text = shift;
            $text=~s/\s+//g;
            return $text;
        }
    );

The first argument is the template text string, which can be both B<text strings> and C<byte strings>.

This filter is applied only to files, not a string template for C<render_string>.

=back

=head3 B<< $tx->render($file, \%vars) :Str >>

Renders a template file with given variables, and returns the result.
I<\%vars> is optional.

Note that I<$file> may be cached according to the cache level.

=head3 B<< $tx->render_string($string, \%vars) :Str >>

Renders a template string with given variables, and returns the result.
I<\%vars> is optional.

Note that I<$string> is never cached, so this method should be avoided in
production environment. If you want in-memory templates, consider the I<path>
option for HASH references which are cached as you expect:

    my %vpath = (
        'hello.tx' => 'Hello, <: $lang :> world!',
    );

    my $tx = Text::Xslate->new( path => \%vpath );
    print $tx->render('hello.tx', { lang => 'Xslate' });

Note that I<$string> must be a text string, not a binary string.

=head3 B<< $tx->load_file($file) :Void >>

Loads I<$file> into memory for following C<render()>.
Compiles and saves it as disk caches if needed.

=head3 B<< Text::Xslate->current_engine :XslateEngine >>

Returns the current Xslate engine while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

=head3 B<< Text::Xslate->current_vars :HashRef >>

Returns the current variable table, namely the second argument of
C<render()> while executing. Otherwise returns C<undef>.

=head3 B<< Text::Xslate->current_file :Str >>

Returns the current file name while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

=head3 B<< Text::Xslate->current_line :Int >>

Returns the current line number while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

=head3 B<< Text::Xslate->print(...) :Void >>

Adds the argument into the output buffer. This method is available on executing.

=head2 Exportable functions

=head3 C<< mark_raw($str :Str) :RawStr >>

Marks I<$str> as raw, so that the content of I<$str> will be rendered as is,
so you have to escape these strings by yourself.

For example:

    my $tx   = Text::Xslate->new();
    my $tmpl = 'Mailaddress: <: $email :>';
    my %vars = (
        email => mark_raw('Foo &lt;foo at example.com&gt;'),
    );
    print $tx->render_string($tmpl, \%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

This function is available in templates as the C<mark_raw> filter, although
the use of it is strongly discouraged.

=head3 C<< unmark_raw($str :Str) :Str >>

Clears the raw marker from I<$str>, so that the content of I<$str> will
be escaped before rendered.

This function is available in templates as the C<unmark_raw> filter.

=head3 C<< html_escape($str :Str) :RawStr >>

Escapes HTML meta characters in I<$str>, and returns it as a raw string (see above).
If I<$str> is already a raw string, it returns I<$str> as is.

By default, this function will be automatically applied to all the template
expressions.

This function is available in templates as the C<html> filter, but you'd better
to use C<unmark_raw> to ensure expressions to be html-escaped.

=head3 C<< uri_escape($str :Str) :Str >>

Escapes URI unsafe characters in I<$str>, and returns it.

This function is available in templates as the C<uri> filter.

=head3 C<< html_builder { block } | \&function :CodeRef >>

Wraps a block or I<&function> with C<mark_raw> so that the new subroutine
will return a raw string.

This function is used to tell the xslate engine that I<&function> is an
HTML builder that returns HTML sources. For example:

    sub some_html_builder {
        my @args = @_;
        my $html;
        # build HTML ...
        return $html;
    }

    my $tx = Text::Xslate->new(
        function => {
            some_html_builder => html_builder(\&some_html_builder),
        },
    );

See also L<Text::Xslate::Manual::Cookbook>.

=head2 Command line interface

The C<xslate(1)> command is provided as a CLI to the Text::Xslate module,
which is used to process directory trees or to evaluate one liners.
For example:

    $ xslate -Dname=value -o dest_path src_path

    $ xslate -e 'Hello, <: $ARGV[0] :> wolrd!' Xslate
    $ xslate -s TTerse -e 'Hello, [% ARGV.0 %] world!' TTerse

See L<xslate(1)> for details.

=head1 TEMPLATE SYNTAX

There are multiple template syntaxes available in Xslate.

=over

=item Kolon

B<Kolon> is the default syntax, using C<< <: ... :> >> inline code and
C<< : ... >> line code, which is explained in L<Text::Xslate::Syntax::Kolon>.

=item Metakolon

B<Metakolon> is the same as Kolon except for using C<< [% ... %] >> inline code and
C<< %% ... >> line code, instead of C<< <: ... :> >> and C<< : ... >>.

=item TTerse

B<TTerse> is a syntax that is a subset of Template-Toolkit 2 (and partially TT3),
which is explained in L<Text::Xslate::Syntax::TTerse>.

=item HTMLTemplate

There's HTML::Template compatible layers in CPAN.

L<Text::Xslate::Syntax::HTMLTemplate> is a syntax for HTML::Template.

L<HTML::Template::Parser> is a converter from HTML::Template to Text::Xslate.

=back

=head1 NOTES

There are common notes in Xslate.

=head2 Nil/undef handling

Note that nil (i.e. C<undef> in Perl) handling is different from Perl's.
Basically it does nothing, but C<< verbose => 2 >> will produce warnings on it.

=over

=item to print

Prints nothing.

=item to access fields

Returns nil. That is, C<< nil.foo.bar.baz >> produces nil.

=item to invoke methods

Returns nil. That is, C<< nil.foo().bar().baz() >> produces nil.

=item to iterate

Dealt as an empty array.

=item equality

C<< $var == nil >> returns true if and only if I<$var> is nil.

=back

=head1 DEPENDENCIES

Perl 5.8.1 or later.

C compiler

=head1 TODO

=over

=item *

Context controls. e.g. C<< <: [ $foo->bar @list ] :> >>.

=item *

Augment modifiers.

=item *

Default arguments and named arguments for macros.

=item *

External macros.

Just idea: in the new macro concept, macros and external templates will be
the same in internals:

    : macro foo($lang) { "Hello, " ~ $lang ~ " world!" }
    : include foo { lang => 'Xslate' }
    : # => 'Hello, Xslate world!'

    : extern bar 'my/bar.tx';     # 'extern bar $file' is ok
    : bar( value => 42 );         # calls an external template
    : include bar { value => 42 } # ditto

=item *

A "too-safe" HTML escaping filter which escape all the symbolic characters

=back

=cut

=head1 RESOURCES

WEB: L<http://xslate.org/>

ML: L<http://groups.google.com/group/xslate>

IRC: #xslate @ irc.perl.org

PROJECT HOME: L<http://github.com/xslate/>

REPOSITORY: L<http://github.com/xslate/p5-Text-Xslate/>

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT. Patches are welcome :)

=head1 SEE ALSO

Documents:

L<Text::Xslate::Manual>

Xslate template syntaxes:

L<Text::Xslate::Syntax::Kolon>

L<Text::Xslate::Syntax::Metakolon>

L<Text::Xslate::Syntax::TTerse>

Xslate command:

L<xslate>

Other template modules that Xslate has been influenced by:

L<Text::MicroTemplate>

L<Text::MicroTemplate::Extended>

L<Text::ClearSilver>

L<Template> (Template::Toolkit)

L<HTML::Template>

L<HTML::Template::Pro>

L<Template::Alloy>

L<Template::Sandbox>

Benchmarks:

L<Template::Benchmark>

L<http://xslate.org/benchmark.html>

Papers:

L<http://www.cs.usfca.edu/~parrt/papers/mvc.templates.pdf> -  Enforcing Strict Model-View Separation in Template Engines

=head1 ACKNOWLEDGEMENT

Thanks to lestrrat for the suggestion to the interface of C<render()>,
the contribution of Text::Xslate::Runner (was App::Xslate), and a lot of
suggestions.

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug finding.

Thanks to gardejo for the proposal to the name B<template cascading>.

Thanks to makamaka for the contribution of Text::Xslate::PP.

Thanks to jjn1056 to the concept of template overlay (now implemented as C<cascade with ...>).

Thanks to typester for the various inspirations.

Thanks to clouder for the patch of adding C<AND> and C<OR> to TTerse.

Thanks to punytan for the documentation improvement.

Thanks to chiba for the bug reports and patches.

Thanks to turugina for the patch to fix Win32 problems

Thanks to Sam Graham for the bug reports.

Thanks to Mons Anderson for the bug reports and patches.

Thanks to hirose31 for the feature requests and bug reports.

Thanks to c9s for the contribution of the documents.

Thanks to shiba_yu36 for the bug reports.

Thanks to kane46taka for the bug reports.

Thanks to cho45 for the bug reports.

Thanks to shmorimo for the bug reports.

Thanks to ueda for the suggestions.

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji@cpan.orgE<gt>.

Makamaka Hannyaharamitu (makamaka) (Text::Xslate::PP)

Maki, Daisuke (lestrrat) (Text::Xslate::Runner)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010-2013, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
