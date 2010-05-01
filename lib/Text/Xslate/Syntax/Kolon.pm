package Text::Xslate::Syntax::Kolon;
use 5.010;
use Mouse;

extends qw(Text::Xslate::Parser);

no Mouse;
__PACKAGE__->meta->make_immutable();

__END__

=head1 NAME

Text::Xslate::Syntax::Kolon - The default template syntax

=head1 SYNOPSIS

    use Text::Xslate;
    my $tx = Text::Xslate->new(
        syntax => 'Kolon',                         # This is the default
        string => 'Hello, <: $dialect :> world!',
    );

    print $tx->render({ dialect => 'Kolon' });

=head1 DESCRIPTION

Kolon is the default syntax, using C<< <: ... :> >> tags and C<< : ... >> line code.

=head1 EXAMPLES

=head2 Variable access

    <: $var :>
    <: $var.0 :>
    <: $var.field :>
    <: $var.accessor :>

    <: $var["field"] :>
    <: $var[0] :>

Variables may be HASH references, ARRAY references, or objects.

=head2 Loop for array references

    : for $data ->($item) {
        [<: $item.field :>]
    : }

=head2 Conditional statements

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

    : $var.value == nil ? "nil" : $var.value

=head2 Expressions

Relational operators (C<< == != < <= > >= >>):

    : $var == 10 ? "10"     : "not 10"
    : $var != 10 ? "not 10" : "10"

Arithmetic operators (C<< + - * / % >>):

    : $var * 10_000
    : ($var % 10) == 0

Logical operators (C<< || && // >>)

    : $var >= 0 && $var <= 10 ? "ok" : "too smaller or too larger"
    : $var // "foo" # as a default value

String operators (C<< ~ >>)

    : "[" ~ $var ~ "]" # concatination

Operator precedence:

    (TODO)

=head2 Functions and filters

Once you have registered functions, you can call them with C<()> or C<|>.

    : f()        # without args
    : f(1, 2, 3) # with args
    : 42 | f     # the same as f(42)

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
    : $value | indent("> ")
    : indent("> ")($value)

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
    :   $x + $y;
    : }
    : add(10, 20)

    : macro signeture -> {
        This is foo version <: $VERSION :>
    : }
    : signeture()

Note that return values of macros are values that their routines renders.
That is, macros themselves output nothing.

=head1 SEE ALSO

L<Text::Xslate>

=cut
