package Text::Xslate;

use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.001_03';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

our $DEBUG;
$DEBUG = $ENV{XSLATE} // $DEBUG // '';

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
my $STRING  = qr/(?: $dquoted | $squoted )/xms;
my $NUMBER  = qr/(?: [+-]? [0-9]+ (?: \. [0-9]+)? )/xms;

my $IDENT   = qr/(?: [.]? [a-zA-Z_][a-zA-Z0-9_]* )/xms;

my $XSLATE_MAGIC = ".xslate $VERSION\n";

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    $args{path}         //= [ $class->default_path ];
    $args{input_layer}  //= ':utf8';
    $args{auto_compile} //= 1;
    $args{compiler}     //= 'Text::Xslate::Compiler';
   #$args{functions}    //= {}; # see _compiler()

    $args{template}       = {};

    my $self = bless \%args, $class;

    if(my $file = $args{file}) {
        $self->_load_file($_)
            for ref($file) ? @{$file} : $file;
    }

    my $source = 0;

    if($args{string}) {
        $source++;
        $self->_load_string('<input>' => $args{string});
    }

    if($args{assembly}) {
        $source++;
        $self->_load_assembly('<input>' => $args{assembly});
    }

    if($args{protocode}) {
        $source++;
        $self->_initialize('<input>' => $args{protocode});
    }

    if($source > 1) {
        $self->throw_error("Multiple template sources are specified");
    }

    return $self;
}

sub default_path {
    require FindBin;
    require File::Basename;
    no warnings 'once';
    return( File::Basename::dirname($FindBin::Bin) . "/template" );
}

sub name { $_[0]->{name} }

sub render;

sub _initialize;

sub _load_file {
    my($self, $file) = @_;

    my $fullpath;
    my $is_assembly = 0;

    foreach my $p(@{ $self->{path} }) {
        $fullpath = "$p/${file}";
        if(-f "${fullpath}c") {
            my $m1 = -M _;
            my $m2 = -M $fullpath;

            if($m1 == $m2) {
                $fullpath     .= 'c';
                $is_assembly   = 1;
            }
            last;
        }
        elsif(-f $fullpath) {
            last;
        }
        else {
            $fullpath = undef;
        }
    }

    if(not defined $fullpath) {
        $self->throw_error("Cannot find $file (path: @{$self->{path}})");
    }

    $self->{name}     = $file;
    $self->{fullpath} = $fullpath;

    my $string;
    {
        open my($in), '<' . $self->{input_layer}, $fullpath
            or $self->throw_error("Cannot open $fullpath for reading: $!");

        if($is_assembly && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $fullpath or Carp::croak("Cannot unlink $fullpath: $!");
            goto &_load_file; # retry
        }
        local $/;
        $string = <$in>;
    }

    if($is_assembly) {
        $self->_load_assembly($file, $string);
    }
    else {
        my $protocode = $self->_compiler->compile($string);

        if($self->{auto_compile}) {
            # compile templates into assemblies
            open my($out), '>:raw:utf8', "${fullpath}c"
                or $self->throw_error("Cannot open ${fullpath}c for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);
            if(!close $out) {
                 Carp::carp("Xslate: Cannot close ${fullpath}c (ignored): $!");
                 unlink "${fullpath}c";
            }
            else {
                my $mtime = ( stat $fullpath )[9];
                utime $mtime, $mtime, "${fullpath}c";
            }
        }

        $self->_initialize($file, $protocode);
    }
    return;
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
                $self->throw_error("Xslate: Cannot load the compiler: $@");
            }
        }

        $compiler = $compiler->new();

        if(my $funcs = $self->{function}) {
            while(my $name = each %{$funcs}) {
                my $symbol = $compiler->symbol($name);
                $symbol->set_nud(sub {
                    my($p, $s) = @_;
                    my $f = $s->clone(arity => 'function');
                    $p->reserve($f);
                    return $f;
                });
                $symbol->value($name);
            }
        }
    }

    return $compiler;
}

sub _load_string {
    my($self, $name, $string) = @_;

    my $protocode = $self->_compiler->compile($string);
    $self->_initialize($name, $protocode);
    return;
}

sub _load_assembly {
    my($self, $name, $assembly) = @_;

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

    $self->_initialize($name, \@protocode);
    return;
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

Text::Xslate - High performance template engine (ALPHA)

=head1 VERSION

This document describes Text::Xslate version 0.001_03.

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
    my $tx = Text::Xslate->new(file => [qw(hello.tx)]);
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

=head1 DESCRIPTION

B<Text::Xslate> is a template engine tuned for persistent applications.
This engine introduces virtual machines. That is, templates are compiled
into xslate opcodes, and then executed by the xslate virtual machine just
like as Perl does.

This software is under development. Any interfaces will be changed.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) -> TX >>

Creates a new xslate template code.

Options:

=over

=item C<< string => $template_string >>

=item C<< file => $template_file | \@template_files >>

=item C<< path => \@path // ["$FindBin::Bin/../template"] >>

=item C<< function => \%functions >>

=item C<< auto_compile => $bool // true >>

=back

=head3 B<< $tx->render($name, \%vars) -> Str >>

Renders a template with variables, and returns the result.

=head1 TEMPLATE SYNTAX

TODO

=head1 EXAMPLES

=head2 Variable access

    <:= $var :>
    <:= $var.field :>
    <:= $var["field"] :>

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

=head2 Template inheritance

(NOT YET IMPLEMENTED)

Base templates F<mytmpl/base.tx>:

    : block title -> { # with default
        [My Template!]
    : }

    : block body is abstract # without default

Derived templates F<mytmpl/foo.tx>:

    : extends base
    : # use default title
    : override body {
        My Template Body!
    : }

Derived templates F<mytmpl/bar.tx>:

    : extends foo
    : # use default title
    : before body {
        Before body!
    : }
    : after body {
        After body!
    : }

Then, Perl code:

    my $tx = Text::Xslate->new( file => 'mytmpl/bar.tx' );
    $tx->render({});

Output:

        [My Template!]

        Before body!
        My Template Body!
        Before Body!

=head1 TODO

=over

=item *

Documentation

=item *

Template inheritance (like Text::MicroTemplate::Extended)

=item *

Opcode-to-XS compiler

=back

=head1 DEPENDENCIES

Perl 5.10.0 or later, and a C compiler.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<Text::MicroTemplate>

L<Text::ClearSilver>

L<Template>

L<HTML::Template>

L<HTML::Template::Pro>

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Goro Fuji (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlartistic> for details.

=cut
