package Text::Xslate;

# The Xslate engine class

use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.1003';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use parent qw(Exporter);
our @EXPORT_OK = qw(escaped_string);

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    find_file literal_to_value
);

use constant _DUMP_LOAD_FILE => ($DEBUG =~ /\b dump=load_file \b/xms);

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

my $XSLATE_MAGIC = ".xslate $VERSION\n";

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    $args{suffix}       //= '.tx';
    $args{path}         //= [ '.' ];
    $args{input_layer}  //= ':utf8';
    $args{cache}        //= 1;
    $args{compiler}     //= 'Text::Xslate::Compiler';
   #$args{function}     //= {}; # see _compiler()

    $args{template}       = {};

    my $self = bless \%args, $class;

    if(my $file = $args{file}) {
        $self->load_file($_)
            for ref($file) ? @{$file} : $file;
    }

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
        $source++;
        $protocode = $self->_compiler->compile($self->{string});
    }

    if($self->{assembly}) {
        $source++;
        $protocode = $self->_load_assembly($self->{assembly});
    }

    if($self->{protocode}) {
        $source++;
        $protocode = $self->{protocode};
    }

    if($source > 1) {
        $self->throw_error("Multiple template sources are specified");
    }

    if(defined $protocode) {
        $self->_initialize($protocode);
    }

    #use Data::Dumper;$Data::Dumper::Indent=1;print Dumper $protocode;

    return $protocode;
}

sub load_file {
    my($self, $file) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;

    if($file eq '<input>') { # simply reload it
        return $self->_load_input()
            // $self->throw_error("LoadError: Template source <input> does not exist");
    }

    my $f = find_file($file, $self->{path});

    if(not defined $f) {
        $self->throw_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    my $fullpath    = $f->{fullpath};
    my $is_compiled = $f->{is_compiled};

    print STDOUT "---> $fullpath ($is_compiled)\n" if _DUMP_LOAD_FILE;

    my $pathc = $fullpath . "c";

    my $string;
    {
        open my($in), '<' . $self->{input_layer}, $is_compiled ? $pathc : $fullpath
            or $self->throw_error("LoadError: Cannot open $fullpath for reading: $!");

        if($is_compiled && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $pathc or $self->throw_error("LoadError: Cannot unlink $pathc: $!");
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
            # compile templates into assemblies
            open my($out), '>:raw:utf8', $pathc
                or $self->throw_error("LoadError: Cannot open $pathc for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $pathc (ignored): $!");
                 unlink $pathc;
            }
            else {
                $is_compiled = 1;
            }
        }
    }
    # if $mtime is undef, the runtime does not check freshness of caches.
    my $mtime;
    if($self->{cache} < 2) {
        if($is_compiled) {
            $mtime = $f->{cache_mtime} // ( stat $pathc )[9];
        }
        else {
            $mtime = 0; # no compiled cache, always need to reload
        }
    }

    $self->_initialize($protocode, $file, $fullpath, $mtime);
    return $protocode;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        if(!$compiler->can('new')){
            my $f = $compiler;
            $f =~ s{::}{/}g;
            $f .= ".pm";

            my $e = do {
                local $@;
                eval { require $f };
                $@;
            };
            if($e) {
                $self->throw_error("Xslate: Cannot load the compiler: $e");
            }
        }

        $compiler = $compiler->new(engine => $self);

        if(my $funcs = $self->{function}) {
            $compiler->define_function(keys %{$funcs});
        }

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub _load_assembly {
    my($self, $assembly) = @_;

    # name ?arg comment
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

1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.1003.

=head1 SYNOPSIS

    use Text::Xslate;
    use FindBin qw($Bin);

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            { title => 'River out of Eden'     },
            { title => 'Beautiful code'        },
        ],
    );

    # for multiple files
    my $tx = Text::Xslate->new();
    print $tx->render_file('hello.tx', \%vars);

    # for strings
    my $template = q{
        <h1><:= $title :></h1>
        <ul>
        : for $books ->($book) {
            <li><:= $book.title :></li>
        : } # for
        </ul>
    };

    $tx = Text::Xslate->new(
        string => $template,
    );

    print $tx->render(\%vars);

    # you can tell the engine that some strings are already escaped.
    use Text::Xslate qw(escaped_string);

    $vars{email} = escaped_string('gfx &lt;gfuji at cpan.org&gt;');
    # or
    $vars{email} = Text::Xslate::EscapedString->new(
        'gfx &lt;gfuji at cpan.org&gt;',
    ); # if you don't want to pollute your namespace.

=head1 DESCRIPTION

B<Text::Xslate> is a template engine tuned for persistent applications.
This engine introduces the virtual machine paradigm. That is, templates are
compiled into xslate opcodes, and then executed by the xslate virtual machine
just like as Perl does.

Note that B<this software is under development>.

=head2 Features

=head3 High performance

Xslate has an virtual machine written in XS, which is highly optimized.
According to benchmarks, Xslate is B<2-10> times faster than other template
engines (Template-Toolkit, HTML::Template::Pro, Text::MicroTemplate, etc).

=head3 Template cascading

Xslate supports template cascading, which allows one to extend
templates with block modifiers.

This mechanism is also called as template inheritance.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) -> Xslate >>

Creates a new xslate template engine.

Possible options ares:

=over

=item C<< string => $template_string >>

Specifies the template string, which is called C<< <input> >> internally.

=item C<< file => $template_file | \@template_files >>

Specifies file(s) to be preloaded.

=item C<< path => \@path // ["."] >>

Specifies the include paths. Default to C<<["."]>>.

=item C<< function => \%functions >>

Specifies functions.

Functions may be called as C<f($arg)> or C<$arg | f>.

=item C<< cache => $level // 1 >>

Sets the cache level.

If I<$level> == 1 (default), Xslate caches compiled templates on the disk, and
checks the freshness of the original templates every time.

If I<$level> E<gt>= 2, caches will be created but the freshness
will not be checked.

I<$level> == 0 creates no caches. It's only for testing.

=item C<< input_layer => $perliolayers // ":utf8" >>

Specifies PerlIO layers for reading templates.

=back

=head3 B<< $tx->render($name, \%vars) -> Str >>

Renders a template with variables, and returns the result.

If I<$name> is omitted, C<< <input> >> is used. See the C<string> option for C<new>.

=head3 Exportable functions

=head3 C<< escaped_string($str :Str) -> EscapedString >>

Mark I<$str> as escaped. Escaped strings will not be escaped by the engine,
so you have to escape these strings.

For example:

    my $tx = Text::Xslate->new(
        string => 'Mailaddress: <:= $email :>',
    );
    my %vars = (
        email => "Foo &lt;foo@example.com&gt;",
    );
    print $tx->render(\%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

=head1 TEMPLATE SYNTAX

TODO

=head1 EXAMPLES

=head2 Variable access

    <:= $var :>
    <:= $var.field :>
    <:= $var["field"] :>
    <:= $var[0] :>

Variables may be HASH references, ARRAY references, or objects.

=head2 Loop (C<for>)

    : for $data ->($item) {
        [<:= $item.field =>]
    : }

Iterating data may be ARRAY references.

=head2 Conditional statement (C<if>)

    : if $var == nil {
        $var is nil.
    : }
    : else if $var != "foo" {
        $var is not nil nor "foo".
    : }
    : else {
        $var is "foo".
    : }

    : if( $var >= 1 && $var <= 10 ) {
        $var is 1 .. 10
    : }

    := $var.value == nil ? "nil" : $var.value

=head2 Expressions

Relational operators (C<< == != < <= > >= >>):

    := $var == 10 ? "10"     : "not 10"
    := $var != 10 ? "not 10" : "10"

Arithmetic operators (C<< + - * / % >>):

    := $var * 10_000
    := ($var % 10) == 0

Logical operators (C<< || && // >>)

    := $var >= 0 && $var <= 10 ? "ok" : "too smaller or too larger"
    := $var // "foo" # as a default value

String operators (C<< ~ >>)

    := "[" ~ $var ~ "]" # concatination

Operator precedence:

    (TODO)

=head2 Functions and filters

Once you have registered functions, you can call them with C<()> or C<|>.

    := f()        # without args
    := f(1, 2, 3) # with args
    := 42 | f     # the same as f(42)

Dynamic functions/filters:

    # code
    sub mk_indent {
        my($prefix) = @_;
        return sub {
            my($str) = @_;
            $str =~ s/^/$prefix/xmsg;
            return $str;
        }
    }
    my $tx = Text::Xslate->new(
        function => {
            indent => \&mk_indent,
        },
    );

    :# template
    := $value | indent("> ")
    := indent("> ")($value)

=head2 Template inclusion

    : include "foo.tx"

Xslate templates may be recursively included, but including depth is
limited to 100.

=head2 Template cascading

You can extend templates with block modifiers.

Base templates F<mytmpl/base.tx>:

    : block title -> { # with default
        [My Template!]
    : }

    : block body -> {;} # without default

Another derived template F<mytmpl/foo.tx>:

    : # cascade "mytmpl/base.tx" is also okey
    : cascade mytmpl::base
    : # use default title
    : around body -> {
        My Template Body!
    : }

Yet another derived template F<mytmpl/bar.tx>:

    : cascade mytmpl::foo
    : around title -> {
        --------------
        : super
        --------------
    : }
    : before body -> {
        Before body!
    : }
    : after body -> {
        After body!
    : }

Then, Perl code:

    my $tx = Text::Xslate->new( file => 'mytmpl/bar.tx' );
    $tx->render({});

Output:

        --------------
        [My Template!]
        --------------

        Before body!
        My Template Body!
        After Body!

This is also called as B<template inheritance>.

=head2 Macro blocks

    : macro add ->($x, $y) {
    :=   $x + $y;
    : }
    := add(10, 20)

    : macro signeture -> {
        This is foo version <:= $VERSION :>
    : }
    := signeture()

Note that return values of macros are values that their routines renders.
That is, macros themselves output nothing.



=head1 TODO

=over

=item *

Template-Toolkit-like syntax

=item *

HTML::Template-like syntax

=back

=head1 DEPENDENCIES

Perl 5.10.0 or later, and a C compiler.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.  Patches are welcome :)

=head1 SEE ALSO

L<Text::MicroTemplate>

L<Text::MicroTemplate::Extended>

L<Text::ClearSilver>

L<Template-Toolkit>

L<HTML::Template>

L<HTML::Template::Pro>

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
