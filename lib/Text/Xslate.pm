package Text::Xslate;
# The Xslate engine class
use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.2011';

use Carp              ();
use File::Spec        ();
use Exporter          ();
use Data::MessagePack ();

use Text::Xslate::Util qw(
    mark_raw unmark_raw
    html_escape escaped_string
    uri_escape html_builder
);

our @ISA = qw(Text::Xslate::Engine);

our @EXPORT_OK = qw(
    mark_raw
    unmark_raw
    escaped_string
    html_escape
    uri_escape
    html_builder
);

my $BYTECODE_VERSION = '1.2';

# $bytecode_version + $fullpath + $compiler_and_parser_options
my $XSLATE_MAGIC   = qq{xslate;$BYTECODE_VERSION;%s;%s;};

# load backend (XS or PP)
if(!exists $INC{'Text/Xslate/PP.pm'}) {
    my $pp = ($Text::Xslate::Util::DEBUG =~ /\b pp \b/xms or $ENV{PERL_ONLY});
    if(!$pp) {
        eval {
            require XSLoader;
            XSLoader::load(__PACKAGE__, $VERSION);
        };
        die $@ if $@ && $Text::Xslate::Util::DEBUG =~ /\b xs \b/xms; # force XS
    }
    if(!__PACKAGE__->can('render')) {
        require 'Text/Xslate/PP.pm';
    }
}

# workaround warnings about numeric when it is a developpers' version
# it must be here because the bootstrap routine requires the under bar.
$VERSION =~ s/_//;

package Text::Xslate::Engine;

use Text::Xslate::Util qw(
    import_from
    make_error
);

BEGIN {
    our @ISA = qw(Exporter);

    my $dump_load = scalar($Text::Xslate::Util::DEBUG =~ /\b dump=load \b/xms);
    *_DUMP_LOAD = sub(){ $dump_load };

    *_ST_MTIME = sub() { 9 }; # see perldoc -f stat

    my $cache_dir = '.xslate_cache';
    foreach my $d($ENV{HOME}, File::Spec->tmpdir) {
        if(defined($d) and -d $d and -w _) {
            $cache_dir = File::Spec->catfile($d, '.xslate_cache');
            last;
        }
    }
    *_DEFAULT_CACHE_DIR = sub() { $cache_dir };
}

# the real defaults are dfined in the parser
my %parser_option = (
    line_start => undef,
    tag_start  => undef,
    tag_end    => undef,
);

# the real defaults are defined in the compiler
my %compiler_option = (
    syntax     => undef,
    type       => undef,
    header     => undef,
    footer     => undef,
);

my %builtin = (
    raw          => \&Text::Xslate::Util::mark_raw,
    html         => \&Text::Xslate::Util::html_escape,
    mark_raw     => \&Text::Xslate::Util::mark_raw,
    unmark_raw   => \&Text::Xslate::Util::unmark_raw,
    uri          => \&Text::Xslate::Util::uri_escape,
    is_array_ref => \&_builtin_is_array_ref,
    is_hash_ref  => \&_builtin_is_hash_ref,

    dump       => \&Text::Xslate::Util::p,
);

sub default_functions { +{} } # overridable

sub options { # overridable
    return {
        # name       => default
        suffix       => '.tx',
        path         => ['.'],
        input_layer  => ':utf8',
        cache        => 1, # 0: not cached, 1: checks mtime, 2: always cached
        cache_dir    => _DEFAULT_CACHE_DIR,
        module       => undef,
        function     => undef,
        compiler     => 'Text::Xslate::Compiler',

        verbose      => 1,
        warn_handler => undef,
        die_handler  => undef,

        %parser_option,
        %compiler_option,
    };
}

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    my $options = $class->options;
    my $used    = 0;
    my $nargs   = scalar keys %args;
    while(my $key = each %{$options}) {
        if(exists $args{$key}) {
            $used++;
        }
        if(!defined($args{$key}) && defined($options->{$key})) {
            $args{$key} = $options->{$key};
        }
    }

    if($used != $nargs) {
        my @unknowns = grep { !exists $options->{$_} } keys %args;
        warnings::warnif(misc => "$class: Unknown option(s): " . join ' ', @unknowns);
    }

    $args{path} = [
        map { ref($_) ? $_ : File::Spec->rel2abs($_) }
            ref($args{path}) eq 'ARRAY' ? @{$args{path}} : $args{path}
    ];

    # function
    my %funcs;
    $class->_merge_hash(\%funcs, $class->default_functions());

    # 'module' overrides default functions
    if(defined $args{module}) {
        $class->_merge_hash(\%funcs, import_from(@{$args{module}}));
    }

    # 'function' overrides imported functons
    $class->_merge_hash(\%funcs, $args{function});

    # the following functions are not overridable
    foreach my $name(keys %builtin) {
        if(exists $funcs{$name}) {
            warnings::warnif(redefine =>
                "$class: You cannot redefine builtin function '$name',"
                . " because it is embeded in the engine");
        }
        $funcs{$name} = $builtin{$name};
    }

    $args{function} = \%funcs;

    # internal data
    $args{template} = {};

    return bless \%args, $class;
}

sub _merge_hash {
    my($self, $base, $add) = @_;
    while(my($name, $body) = each %{$add}) {
        $base->{$name} = $body;
    }
    return;
}

sub load_string { # for <string>
    my($self, $string) = @_;
    if(not defined $string) {
        $self->_error("LoadError: Template string is not given");
    }
    $self->{string_buffer} = $string;
    my $asm = $self->compile($string);
    $self->_assemble($asm, '<string>', \$string, undef, undef);
    return $asm;
}

my $updir = File::Spec->updir;
sub find_file {
    my($self, $file) = @_;

    if($file =~ /\Q$updir\E/xmso) {
        $self->_error("LoadError: Forbidden component (updir: '$updir') found in file name '$file'");
    }

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;
    foreach my $p(@{$self->{path}}) {
        print STDOUT "  find_file: $p / $file ...\n" if _DUMP_LOAD;

        my $path_id;
        if(ref $p eq 'HASH') { # virtual path
            defined(my $content = $p->{$file}) or next;
            $fullpath   = \$content;
            # TODO: we should provide a way to specify this mtime
            #       (like as Template::Provider?)
            $orig_mtime = $^T;
            $path_id    = 'HASH';
        }
        else {
            $fullpath = File::Spec->catfile($p, $file);
            defined($orig_mtime = (stat($fullpath))[_ST_MTIME])
                or next;
            $path_id    = Text::Xslate::uri_escape($p);
        }

        # $file is found
        $cachepath = File::Spec->catfile(
            $self->{cache_dir},
            $path_id,
            $file . 'c',
        );
        $cache_mtime = (stat($cachepath))[_ST_MTIME]; # may fail, but doesn't matter
        last;
    }

    if(not defined $orig_mtime) {
        $self->_error("LoadError: Cannot find '$file' (path: @{$self->{path}})");
    }

    print STDOUT "  find_file: $fullpath (", ($cache_mtime || 0), ")\n" if _DUMP_LOAD;

    return {
        fullpath    => $fullpath,
        cachepath   => $cachepath,

        orig_mtime  => $orig_mtime,
        cache_mtime => $cache_mtime,
    };
}


sub load_file {
    my($self, $file, $mtime, $from_include) = @_;

    local $self->{from_include} = $from_include;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD;

    if($file eq '<string>') { # simply reload it
        return $self->load_string($self->{string_buffer});
    }

    my $fi = $self->find_file($file);

    my $asm = $self->_load_compiled($fi, $mtime) || $self->_load_source($fi, $mtime);

    # $cache_mtime is undef : uses caches without any checks
    # $cache_mtime > 0      : uses caches with mtime checks
    # $cache_mtime == 0     : doesn't use caches
    my $cache_mtime;
    if($self->{cache} < 2) {
        $cache_mtime = $fi->{cache_mtime} || 0;
    }

    $self->_assemble($asm, $file, $fi->{fullpath}, $fi->{cachepath}, $cache_mtime);
    return $asm;
}

sub slurp {
    my($self, $fullpath) = @_;

    open my($source), '<' . $self->{input_layer}, $fullpath
        or $self->_error("LoadError: Cannot open $fullpath for reading: $!");
    local $/;
    return scalar <$source>;
}

sub _load_source {
    my($self, $fi) = @_;
    my $fullpath  = $fi->{fullpath};
    my $cachepath = $fi->{cachepath};

    # This routine is called when the cache is no longer valid (or not created yet)
    # so it should be ensured that the cache, if exists, does not exist
    if(-e $cachepath) {
        unlink $cachepath
            or Carp::carp("Xslate: cannot unlink $cachepath (ignored): $!");
    }

    my $source = $self->slurp($fullpath);

    my $asm = $self->compile($source,
        file => $fullpath,
    );

    if($self->{cache} >= 1) {
        my($volume, $dir) = File::Spec->splitpath($fi->{cachepath});
        my $cachedir      = File::Spec->catpath($volume, $dir, '');
        if(not -e $cachedir) {
            require File::Path;
            eval { File::Path::mkpath($cachedir) }
                or Carp::carp("Xslate: Cannot make directory $cachepath (ignored): $@");
        }

        if(open my($out), '>:raw', $cachepath) {
            $self->_save_compiled($out, $asm, $fullpath, utf8::is_utf8($source));

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $cachepath;
            }
            else {
                $fi->{cache_mtime} = ( stat $cachepath )[_ST_MTIME];
            }
        }
        else {
            Carp::carp("Xslate: Cannot open $cachepath for writing (ignored): $!");
        }
    }
    if(_DUMP_LOAD) {
        printf STDERR "  _load_source: cache(%s)\n",
            defined $fi->{cache_mtime} ? $fi->{cache_mtime} : 'undef';
    }

    return $asm;
}

# load compiled templates if they are fresh enough
sub _load_compiled {
    my($self, $fi, $threshold) = @_;

    if($self->{cache} >= 2) {
        # threshold is the most latest modified time of all the related caches,
        # so if the cache level >= 2, they seems always fresh.
        $threshold = 9**9**9; # force to purge the cache
    }
    else {
        $threshold ||= $fi->{cache_mtime};
    }
    # see also tx_load_template() in xs/Text-Xslate.xs
    if(!( defined($fi->{cache_mtime}) and $self->{cache} >= 1
            and $threshold >= $fi->{orig_mtime} )) {
        printf "  _load_compiled: no fresh cache: %s, %s",
            $threshold, Text::Xslate::Util::p($fi) if _DUMP_LOAD;
        $fi->{cache_mtime} = undef;
        return undef;
    }

    my $cachepath = $fi->{cachepath};
    open my($in), '<:raw', $cachepath
        or $self->_error("LoadError: Cannot open $cachepath for reading: $!");

    my $magic = $self->_magic_token($fi->{fullpath});
    my $data;
    read $in, $data, length($magic);
    if($data ne $magic) {
        return undef;
    }
    else {
        local $/;
        $data = <$in>;
        close $in;
    }
    my $unpacker = Data::MessagePack::Unpacker->new();
    my $offset  = $unpacker->execute($data);
    my $is_utf8 = $unpacker->data();
    $unpacker->reset();

    $unpacker->utf8($is_utf8);

    my @asm;
    while($offset < length($data)) {
        $offset = $unpacker->execute($data, $offset);
        my $c = $unpacker->data();
        $unpacker->reset();

        # my($name, $arg, $line, $file, $symbol) = @{$c};
        if($c->[0] eq 'depend') {
            my $dep_mtime = (stat $c->[1])[_ST_MTIME];
            if(!defined $dep_mtime) {
                Carp::carp("Xslate: Failed to stat $c->[1] (ignored): $!");
                return undef; # purge the cache
            }
            if($dep_mtime > $threshold){
                printf "  _load_compiled: %s(%s) is newer than %s(%s)\n",
                    $c->[1],    scalar localtime($dep_mtime),
                    $cachepath, scalar localtime($threshold)
                        if _DUMP_LOAD;
                return undef; # purge the cache
            }
        }
        push @asm, $c;
    }

    if(_DUMP_LOAD) {
        printf STDERR "  _load_compiled: cache(%s)\n",
            defined $fi->{cache_mtime} ? $fi->{cache_mtime} : 'undef';
    }

    return \@asm;
}

sub _save_compiled {
    my($self, $out, $asm, $fullpath, $is_utf8) = @_;
    local $\;
    print $out $self->_magic_token($fullpath);
    print $out Data::MessagePack->pack($is_utf8 ? 1 : 0);
    foreach my $c(@{$asm}) {
        print $out Data::MessagePack->pack($c);
    }
    return;
}

sub _magic_token {
    my($self, $fullpath) = @_;

    my $opt = Data::MessagePack->pack([
        ref($self->{compiler}) || $self->{compiler},
        $self->_extract_options(\%parser_option),
        $self->_extract_options(\%compiler_option),
    ]);

    if(ref $fullpath) { # ref to content string
        require 'Digest/MD5.pm';
        my $md5 = Digest::MD5->new();
        $md5->add(${$fullpath});
        $fullpath = join ':', ref($fullpath), $md5->hexdigest();
    }
    return sprintf $XSLATE_MAGIC, $fullpath, $opt;
}

sub _extract_options {
    my($self, $opt_ref) = @_;
    my @options;
    foreach my $name(sort keys %{$opt_ref}) {
        if(defined($self->{$name})) {
            push @options, $name => $self->{$name};
        }
    }
    return @options;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        require Any::Moose;
        Any::Moose::load_class($compiler);

        $compiler = $compiler->new(
            engine => $self,
            $self->_extract_options(\%compiler_option),
            parser_option => {
                $self->_extract_options(\%parser_option),
            },
        );

        $compiler->define_function(keys %{ $self->{function} });

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub compile {
    my $self = shift;
    return $self->_compiler->compile(@_, from_include => $self->{from_include});
}

sub _builtin_is_array_ref {
    return ref($_[0]) eq 'ARRAY';
}

sub _builtin_is_hash_ref {
    return ref($_[0]) eq 'HASH';
}

sub _error {
    die make_error(@_);
}

sub dump :method {
    goto &Text::Xslate::Util::p;
}

package Text::Xslate;
1;
__END__

=head1 NAME

Text::Xslate - Scalable template engine for Perl5

=head1 VERSION

This document describes Text::Xslate version 0.2011.

=head1 SYNOPSIS

    use Text::Xslate;

    my $tx = Text::Xslate->new(
        # the fillowing options are optional.
        path       => ['.'],
        cache_dir  => "$ENV{HOME}/.xslate_cache",
        cache      => 1,
    );

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            # ...
        ],
    );

    # for files
    print $tx->render('hello.tx', \%vars);

    # for strings
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

B<Text::Xslate> is a template engine, tuned for persistent applications,
safe as an HTML generator, and with rich features.

The concept of Xslate is strongly influenced by Text::MicroTemplate
and Template-Toolkit 2, but the central philosophy of Xslate is different
from them. That is, the philosophy is B<sandboxing> that the template logic
should not have no access outside the template beyond your permission.

=head2 Features

=head3 High performance

This engine introduces the virtual machine paradigm. Templates are
compiled into intermediate code, and then executed by the virtual machine,
which is highly optimized for rendering templates. Thus, Xslate is
much faster than any other template engines.

Here is a result of F<benchmark/x-rich-env.pl> to compare various template
engines in "rich" environment where applications are persistent and XS modules
are available.

    $ perl -Mblib benchmark/x-rich-env.pl
    Perl/5.10.1 i686-linux
    Text::Xslate/0.2002
    Text::MicroTemplate/0.18
    Text::MicroTemplate::Extended/0.11
    Template/2.22
    Text::ClearSilver/0.10.5.4
    HTML::Template::Pro/0.9503
    1..4
    ok 1 - TT: Template-Toolkit
    ok 2 - MT: Text::MicroTemplate
    ok 3 - TCS: Text::ClearSilver
    ok 4 - HTP: HTML::Template::Pro
    Benchmarks with 'include' (datasize=100)
              Rate     TT     MT    TCS    HTP Xslate
    TT       129/s     --   -84%   -94%   -95%   -99%
    MT       807/s   527%     --   -63%   -71%   -96%
    TCS     2162/s  1580%   168%     --   -23%   -89%
    HTP     2814/s  2087%   249%    30%     --   -85%
    Xslate 19321/s 14912%  2295%   794%   587%     --

According to this result, Xslate is 100+ times faster than Template-Toolkit.
Text::MicroTemplate is a very fast template engine written in pure Perl, but
XS-based modules, namely Text::ClearSilver, HTML::Template::Pro and Xslate
are faster than Text::MicroTemplate. Moreover, Xslate is even faster than
Text::ClearSilver and HTML::Template::Pro.

There are benchmark scripts in the F<benchmark/> directory.

=head3 Auto escaping to HTML meta characters

All the HTML meta characters in template expressions the engine interpolates
into template texts are automatically escaped, so the output has no
possibility to XSS by default.

=head3 Template cascading

Xslate supports B<template cascading>, which allows you to extend
templates with block modifiers. It is like traditional template inclusion,
but is more powerful.

This mechanism is also called as template inheritance.

=head3 Easy to enhance

Xslate is highly extensible. You can add functions and methods to the template
engine and even add a new syntax via extending the parser.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) :XslateEngine >>

Creates a new xslate template engine with options.

Possible options are:

=over

=item C<< path => \@path // ['.'] >>

Specifies the include paths, which may be directory names or virtual paths,
i.e. HASH references which contain C<< $file_name => $content >> pairs.

=item C<< cache => $level // 1 >>

Sets the cache level.

If I<$level> == 1 (default), Xslate caches compiled templates on the disk, and
checks the freshness of the original templates every time.

If I<$level> E<gt>= 2, caches will be created but the freshness
will not be checked.

I<$level> == 0 uses no caches. It's provided for testing.

=item C<< cache_dir => $dir // "$ENV{HOME}/.xslate_cache" >>

Specifies the directory used for caches. If C<$ENV{HOME}> doesn't exist,
C<< File::Spec->tmpdir >> will be used.

You B<should> specify this option on productions.

=item C<< function => \%functions >>

Specifies a function map which contains name-coderef pairs.
A function C<f> may be called as C<f($arg)> or C<$arg | f> in templates.

There are builtin filters which are not overridable.

=item C<< module => [$module => ?\@import_args, ...] >>

Imports functions from I<$module>, which may be a function-based or bridge module.
Optional I<@import_args> are passed to C<import> as C<< $module->import(@import_args) >>.

For example:

    # for function-based modules
    my $tx = Text::Xslate->new(
        module => ['Time::Piece'],
    );
    print $tx->render_string(
        '<: localtime($x).strftime() :>',
        { x => time() },
    ); # => Wed, 09 Jun 2010 10:22:06 JST

    # for bridge modules
    my $tx = Text::Xslate->new(
        module => ['SomeModule::Bridge::Xslate'],
    );
    print $tx->render_string(
        '<: $x.some_method() :>',
        { x => time() },
    );

Because you can use function-based modules with the C<module> option, and
also can invoke any object methods in templates, Xslate doesn't require
specific namespaces for plugins.

=item C<< input_layer => $perliolayers // ':utf8' >>

Specifies PerlIO layers to open template files.

=item C<< verbose => $level // 1 >>

Specifies the verbose level.

If C<< $level == 0 >>, all the possible errors will be ignored.

If C<< $level> >= 1 >> (default), trivial errors (e.g. to print nil) will be ignored,
but severe errors (e.g. for a method to throw the error) will be warned.

If C<< $level >= 2 >>, all the possible errors will be warned.

=item C<< suffix => $ext // '.tx' >>

Specify the template suffix, which is used for template cascading.

=item C<< syntax => $name // 'Kolon' >>

Specifies the template syntax you want to use.

I<$name> may be a short name (e.g. C<Kolon>), or a fully qualified name
(e.g. C<Text::Xslate::Syntax::Kolon>).

This option is passed to the compiler directly.

=item C<< type => $type // 'html' >>

Specifies the output content type. If I<$type> is C<html> or C<xml>,
template expressions are interpolated via the C<html-escape> filter.
If I<$type> is C<text>, template expressions are interpolated as they are.

I<$type> may be B<html>, B<xml> (identical to C<html>), and B<text>.

This option is passed to the compiler directly.

=item C<< line_start => $token // $parser_defined_str >>

Specify the token to start line code as a string, which C<quotemeta> will be applied to.

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

=back

=head3 B<< $tx->render($file, \%vars) :Str >>

Renders a template file with variables, and returns the result.
I<\%vars> is optional.

Note that I<$file> may be cached according to the cache level.

=head3 B<< $tx->render_string($string, \%vars) :Str >>

Renders a template string with variables, and returns the result.
I<\%vars> is optional.

Note that I<$string> is never cached, so this method may not be suitable for
productions.

=head3 B<< $tx->load_file($file) :Void >>

Loads I<$file> into memory for following C<render($file, \%vars)>.
Compiles and saves it as caches if needed.

It is a good idea to load templates before applications fork.
Here is an example to to load all the templates which is in a given path:

    my $path = ...;
    my $tx = Text::Xslate->new(
        path      => [$path],
        cache_dir =>  $path,
    );

    find sub {
        if(/\.tx$/) {
            my $file = $File::Find::name;
            $file =~ s/\Q$path\E .//xsm; # fix path names
            $tx->load_file($file);
        }
    }, $path;

    # fork and render ...


=head3 B<< Text::Xslate->current_engine :XslateEngine >>

Returns the current Xslate engine while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

=head3 B<< Text::Xslate->current_file :Str >>

Returns the current file name while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

=head3 B<< Text::Xslate->current_line :Int >>

Returns the current line number while executing. Otherwise returns C<undef>.
This method is significant when it is called by template functions and methods.

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
the use of it is discouraged.

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

Wraps I<&function> with C<mark_raw> so that the new subroutine returns
a raw string.

This function is used to tell the xslate engine that I<&function> is an
HTML builder that returns HTML sources. For example:

    sub some_html_builder {
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

    $ xslate -D name=value -o dest_path src_path

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

If you have a C compiler, the XS backend will be used. Otherwise the pure Perl
backend will be used.

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

L<xlsate>

The Xslate web site and public repository:

L<http://xslate.org/>

L<http://github.com/gfx/p5-Text-Xslate>

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

=head1 ACKNOWLEDGEMENT

Thanks to lestrrat for the suggestion to the interface of C<render()>,
the contribution of Text::Xslate::Runner (was App::Xslate), and a lot of
suggestions.

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug finding.

Thanks to gardejo for the proposal to the name B<template cascading>.

Thanks to jjn1056 to the concept of template overlay (now implemented as C<cascade with ...>).

Thanks to makamaka for the contribution of Text::Xslate::PP.

Thanks to typester for the various inspirations.

Thanks to clouder for the patch of adding C<AND> and C<OR> to TTerse.

Thanks to punytan for the documentation improvement.

Thanks to chiba for the bug reports and patches.

Thanks to turugina for the patch to fix Win32 problems

Thanks to Sam Graham to the bug reports.

Thanks to Mons Anderson to the bug reports and patches.

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji(at)cpan.orgE<gt>

Makamaka Hannyaharamitu (makamaka) (Text::Xslate::PP)

Maki, Daisuke (lestrrat) (Text::Xslate::Runner)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
