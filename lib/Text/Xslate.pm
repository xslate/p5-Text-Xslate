package Text::Xslate;

# The Xslate engine class

use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.1000';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use parent qw(Exporter);
our @EXPORT_OK = qw(escaped_string);

use Text::Xslate::Util;

use constant _DUMP_LOAD_FILE => ($Text::Xslate::DEBUG =~ /\b dump=load_file \b/xms);

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
my $STRING  = qr/(?: $dquoted | $squoted )/xms;
my $NUMBER  = qr/(?: [+-]? [0-9]+ (?: \. [0-9]+)? )/xms;

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
   #$args{functions}    //= {}; # see _compiler()

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
        $protocode = $self->_load_string($self->{string});
    }

    if($self->{assembly}) {
        $source++;
        $protocode = $self->_load_assembly($self->{assembly});
    }

    if($self->{protocode}) {
        $source++;
        $self->_initialize($protocode = $self->{protocode});
    }

    if($source > 1) {
        $self->throw_error("Multiple template sources are specified");
    }

    #use Data::Dumper;$Data::Dumper::Indent=1;print Dumper $protocode;

    return $protocode;
}

sub load_file {
    my($self, $file) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;

    if($file eq '<input>') { # simply reload it
        return $self->_load_input() // $self->throw_error("Template source <input> does not exist");
    }

    my $f = Text::Xslate::Util::find_file($file, $self->{path});

    if(not defined $f) {
        $self->throw_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    my $fullpath    = $f->{fullpath};
    my $mtime       = $f->{mtime};
    my $is_compiled = $f->{is_compiled};

    print STDOUT "---> $fullpath\n" if _DUMP_LOAD_FILE;

    # if $mtime is undef, the runtime does not check freshness of caches.
    undef $mtime if $self->{cache} >= 2;

    my $string;
    {
        open my($in), '<' . $self->{input_layer}, $fullpath
            or $self->throw_error("LoadError: Cannot open $fullpath for reading: $!");

        if($is_compiled && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $fullpath or $self->throw_error("LoadError: Cannot unlink $fullpath: $!");
            goto &load_file; # retry
        }
        local $/;
        $string = <$in>;
    }

    my $protocode;
    if($is_compiled) {
        $protocode = $self->_load_assembly($string, $file, $fullpath, $mtime);
    }
    else {
        $protocode = $self->_compiler->compile($string, file => $file);

        if($self->{cache}) {
            # compile templates into assemblies
            my $pathc = "${fullpath}c";
            open my($out), '>:raw:utf8', $pathc
                or $self->throw_error("LoadError: Cannot open $pathc for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);
            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $pathc (ignored): $!");
                 unlink $pathc;
            }
            else {
                my $t = $mtime // ( stat $fullpath )[9];
                utime $t, $t, $pathc;
            }
        }

        $self->_initialize($protocode, $file, $fullpath, $mtime);
    }
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

sub _load_string {
    my($self, $string, @args) = @_;

    my $protocode = $self->_compiler->compile($string);
    $self->_initialize($protocode, @args);
    return $protocode;
}

sub _load_assembly {
    my($self, $assembly, @args) = @_;

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

        if(defined($value)) {
            if($value =~ s/"(.*)"/$1/){
                $value =~ s/\\n/\n/g;
                $value =~ s/\\t/\t/g;
                $value =~ s/\\(.)/$1/g;
            }
            elsif($value =~ s/'(.*)'/$1/) {
                $value =~ s/\\(['\\])/$1/g; # ' for poor editors
            }
        }
        push @protocode, [ $name, $value, $line ];
    }

    #use Data::Dumper;$Data::Dumper::Indent=1;print Dumper(\@protocode);

    $self->_initialize(\@protocode, @args);
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

This document describes Text::Xslate version 0.1000.

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
just like as Perl does. Accordingly, Xslate is much faster than other template
engines.

Note that B<this software is under development>.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) -> TX >>

Creates a new xslate template code.

Options:

=over

=item C<< string => $template_string >>

Specifies the template string, which is called C<< <input> >> internally.

=item C<< file => $template_file | \@template_files >>

Specifies file(s) to be preloaded.

=item C<< path => \@path // ["."] >>

Specifies the include paths. Default to C<<["."]>>.

=item C<< function => \%functions >>

Specifies functions.

=item C<< cache => $level // 1 >>

Sets the cache level. If I<$level> E<gt>= 2, modified times will not be checked.

=item C<< input_layer => $perliolayers // ":utf8" >>

Specifies PerlIO layers for reading.

=back

=head3 B<< $tx->render($name, \%vars) -> Str >>

Renders a template with variables, and returns the result.

=head3 Exportable functions

=head3 C<< escaped_string($str :Str) -> EscapedString >>

Mark I<$str> as escaped. Escaped strings will not be escaped by the engine,
so you have to escape these strings.

For example:

    my $tx = Text::Xslate->new(
        string => "Mailaddress: <:= $email :>",
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

    := $var + 10
    := ($var % 10) == 0

Logical operators (C<< || && // >>)

    := $var >= 0 && $var <= 10 ? "ok" : "too smaller or too larger"
    := $var // "foo" # as a default value

Operator precedence:

    (TODO)

=head2 Template inclusion

    : include "foo.tx"

Xslate templates may be recursively included, but including depth is
limited to 100.

=head2 Template cascading

Base templates F<mytmpl/base.tx>:

    : block title -> { # with default
        [My Template!]
    : }

    : block body -> {;} # without default

Another derived template F<mytmpl/foo.tx>:

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
    :   x + $y;
    : }
    := add(10, 20)

    : macro signeture -> {
        This is foo version <:= $VERSION :>
    : }
    : signeture()

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
