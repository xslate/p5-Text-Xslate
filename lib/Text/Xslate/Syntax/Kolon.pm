package Text::Xslate::Syntax::Kolon;
use Any::Moose;

extends qw(Text::Xslate::Parser);

no Any::Moose;
__PACKAGE__->meta->make_immutable();

__END__

=head1 NAME

Text::Xslate::Syntax::Kolon - The default template syntax

=head1 SYNOPSIS

    use Text::Xslate;
    my $tx = Text::Xslate->new(
        syntax => 'Kolon', # optional
    );

    print $tx->render_string(
        'Hello, <: $dialect :> world!',
        { dialect => 'Kolon' }
    );

=head1 DESCRIPTION

Kolon is the default syntax, using C<< <: ... :> >> tags and C<< : ... >> line code.

=head1 SYNTAX

=head2 Variable access

Variable access:

    <: $var :>

Field access:

    <: $var.0 :>
    <: $var.field :>
    <: $var.accessor :>

    <: $var["field"] :>
    <: $var[0] :>

Variables may be HASH references, ARRAY references, or objects.
Because C<$var.field> and C<$var["field"]> are the same semantics,
C<< $obj["accessor"] >> syntax may be call object methods.

=head2 Literals

Special:

    : nil   # indicates "nothing"
    : true  # as the integer 1
    : false # as the integer 0

String:

    : "foo\n" # the same as perl
    : 'foo\n' # the same as perl

Number:

    : 42
    : 3.14
    : 0xFF
    : 0b1010

Array:

    : for [1, 2, 3] -> $i { ... }

Hash:

    : foo({ foo => "bar" })

C<{ ... }> is always parsed as hash literals, so you need not to use prefix C<+>
as Perl sometimes requires:

    :  {}.kv(); # ok
    : +{}.kv(); # also ok

=head2 Expressions

Conditional operator (C<< ?: >>):

    : $var.value == nil ? "nil" : $var.value

Relational operators (C<< == != < <= > >= >>):

    : $var == 10 ? "10"     : "not 10"
    : $var != 10 ? "not 10" : "10"

Note that C<==> and C<!=> are similar to Perl's C<eq> and C<ne> except that
C<$var == nil> is true B<iff> I<$var> is uninitialized, while other
relational operators are numerical operators.

Arithmetic operators (C<< + - * / % min max >>):

    : $var * 10_000
    : ($var % 10) == 0
    : 10 min 20 min 30 # 10
    : 10 max 20 max 30 # 30

Logical operators (C<< ! && || // not and or >>)

    : $var >= 0 && $var <= 10 ? "ok" : "too smaller or too larger"
    : $var // "foo" # as a default value

String operators (C<< ~ >>)

    : "[" ~ $var ~ "]" # concatination

Operator precedence is the same as Perl's:

    . () []
    * / %
    + - ~
    < <= > >=
    == !=
    |
    &&
    || // min max
    ?:
    not
    and
    or

=head2 Constants

You can define lexical constants with C<constant>, which requires a bare name,
and C<my>, which requires a variable name.

    : constant FOO = 42;
    : my      $foo = 42;

These two statements has the same semantics, so you cannot modify C<$foo>.

    : my $foo = 42; $foo = 3.14; # compile error!

=head2 Loops

There is C<for> loops that are like Perl's C<foreach>.

    : # $data must be an ARRAY reference
    : for $data -> $item {
        [<: $item.field :>]
    : }

You can get the iterator index in C<for> statements as C<$~ITERATOR_VAR>:

    : for $data -> $item {
        : if ($~item % 2) == 0 {
            Even (0, 2, 4, ...)
        : }
        : else {
            Odd (1, 3, 5, ...)
        : }
    : }

C<$~item> is a pseudo object, so you can access its elements
via the dot-name syntax.

    : for $data -> $i {
        : $~i.index # the same as $~i
        : $~i.count # the same as $~i + 1

        : if ($~i.index % 2) == 0 {
            Even
        : }
        : else {
            Odd
        : }
    : }

Supported iterator elements are C<index :Int>, C<count :Int>,
C<body : ArrayRef>, C<size : Int>, C<max :Int>, C<is_first :Bool>,
and C<is_last :Bool>, C<peek_next :Any>, C<peek_prev :Any>.

C<while> loops are also supported in the same semantics as Perl's:

    : # $obj might be an iteratable object
    : while $dbh.fetch() -> $item {
        [<: $item.field :>]
    : }

=head2 Conditional statements

There are C<if-else> and C<given-when> conditional statements.

C<if-else>:

    : if $var == nil {
        $var is nil.
    : }
    : else if $var != "foo" { # elsif is okay
        $var is not nil nor "foo".
    : }
    : else {
        $var is "foo".
    : }

    : if( $var >= 1 && $var <= 10 ) {
        $var is 1 .. 10
    : }

Note that C<if> doesn't require parens, so the following code is okay:

    : if ($var + 10) == 20 { } # OK

C<given-when>(also known as B<switch statement>):

    : given $var {
    :   when "foo" {
            it is foo.
    :   }
    :   when "bar" {
            it is bar.
    :   }
    :   default {
            it is not foo nor bar.
        }
    : }

You can specify the topic variable.

    : given $var -> $it {
    :   when "foo" {
            it is foo.
    :   }
    :   when $it == "bar" or $it == "baz" {
            it is bar or baz.
    :   }
    : }

=head2 Functions and filters

You can register functions via C<function> or C<module> options for
C<< Text::Xslate->new() >>.

Once you have registered functions, you can call them with the C<()> operator.
The C<|> operator is supported as a syntactic sugar to C<()>.

    : f()        # without args
    : f(1, 2, 3) # with args
    : 42 | f     # the same as f(42)

Functions are Perl's subroutines, so you can define dynamic functions:

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

There are several builtin functions, which you cannot redefine:

    : $var | raw  # not to html-escape it
    : $var | html # explicitly html-escape it (default)
    : $var | dump # dump it with Data::Dumper

NOTE: C<raw> and C<html> might be optimized away by the compiler.

=head2 Methods

When I<$var> is an object instance, you can call its methods with the C<()>
operator.

    <: $var.method() :>
    <: $var.method(1, 2, 3) :>
    <: $var.method( foo => [ 1, 2, 3 ] ) :>

There is an autoboxing mechanism that provides primitive types with builtin
methods.

For arrays:

    <: $array.size() :>
    <: $array.join(",") :>
    <: $array.reverse() :>

For hashes:

    <: $hash.size() :>
    <: $hash.keys().join(", ")   # sorted by keys :>
    <: $hash.values().join(", ") # sorted by keys :>
    <: for $hash.kv() -> $pair { # sorted by keys :>
        <: # $pair is a pair type with key and value fields -:>
        <: $pair.key :> = <: $pair.value :>
    <: } :>

You can define more methods with the C<function> option. See L<Text::Xslate>.

=head2 Template inclusion

Template inclusion is a traditional way to extend templates.

    : include "foo.tx";
    : include "foo.tx" { var1 => value1, var2 => value2, ... };

Xslate templates may be recursively included, but the including depth is
limited to 100.

=head2 Template cascading

Template cascading is another way to extend templates other than C<include>.

First, make base templates F<myapp/base.tx>:

    : block title -> { # with default
        [My Template!]
    : }

    : block body -> { } # without default

Then extend from base templates with the C<cascade> keyword:

    : cascade myapp::base
    : cascade myapp::base { var1 => value1, var2 => value2, ...}
    : cascade myapp::base with myapp::role1, myapp::role2
    : cascade with myapp::role1, myapp::role2

In derived templates, you may extend templates (e.g. F<myapp/foo.tx>)
with block modifiers C<before>, C<around> (or C<override>) and C<after>.

    : # cascade "myapp/base.tx" is also okay
    : cascade myapp::base
    : # use default title
    : around body -> {
        My template body!
    : }

And, make yet another derived template F<myapp/bar.tx>:

    : cascade myapp::foo
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

Then render it as usual.

    my $tx = Text::Xslate->new( file => 'myapp/bar.tx' );
    $tx->render({});

The result is something like this:

        --------------
        [My Template!]
        --------------

        Before body!
        My template tody!
        After body!

You can also cascade templates just like Moose's roles:

    : cascade myapp::base with myapp::role1, myapp::role2

You can omit the base template.

Given a file F<myapp/hello.tx>:

    : around hello -> {
        --------------
        : super
        --------------
    : }

Then the main template:

    : cascade with myapp::hello

    : block hello -> {
        Hello, world!
    : }

Output:

        --------------
        Hello, world!
        --------------

=head2 Macro blocks

Macros are supported, which are called in the same way as functions and
return a string marked as escaped.

    : macro add ->($x, $y) {
    :   $x + $y;
    : }
    : add(10, 20)

    : macro signeture -> {
        This is foo version <: $VERSION :>
    : }
    : signeture()

    : macro factorial -> $x {
    :   $x == 0 ? 1 : $x * factorial($x-1)
    : }
    : factorial(1)  # as a function
    : 1 | factorial # as a filter

Macros are first objects.

    <: macro foo -> { "foo" }
       macro bar -> { "bar" }
       my $dispatcher = {
           foo => foo,
           bar => bar,
       }; -:>
    : $dispatcher{$key}()

Macros returns what their body renders. That is, macros themselves output nothing.

Note that you cannot call macros before their definitions.

=head2 Comments

    :# this is a comment
    <:
      # this is also a comment
      $var
    :>

    <: $foo # this is ok :>

Comments are closed by a new line or semicolon, so the following template
outputs "Hello".

    <: # this is a comment; "Hello" :>

=head1 SEE ALSO

L<Text::Xslate>

=cut
