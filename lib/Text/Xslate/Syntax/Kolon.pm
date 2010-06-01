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

Nil:
    : nil

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

C<$~item> looks like an abstract object, so you can access its elements
via the dot operator.

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

Supported iterator elements are C<index :Int>, C<count :Int>.

C<while> loops are also supported to iterate database-handle-like objects.

    : # $obj must be an iteratable object
    : while $dbh.fetch() -> $item {
        [<: $item.field :>]
    : }

Note that C<while> is B<not the same as Perl's>. In fact, the above Xslate
C<while> code is the same as the following Perl C<while> code:

    while(defined(my $item = $dbh->fetch())) {
        ...
    }

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

Note that C<if> doesn't require parens, so the above code is okay:

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

Once you have registered functions, you can call them with C<()> or C<|>.

    : f()        # without args
    : f(1, 2, 3) # with args
    : 42 | f     # the same as f(42)

You can define dynamic functions/filters:

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

There are several builtin filters:

    : $var | raw  # not to html-escape it
    : $var | html # explicitly html-escape it (default)
    : $var | dump # dump it with Data::Dumper

=head2 Methods

When I<$var> is an object instance, you can call its methods.

    <: $var.method() :>
    <: $var.method(1, 2, 3) :>

For arrays and hashes, there are builtin methods (i.e. there
is an autoboxing mechanism):

    <: $array.size() :>
    <: $array.join(",") :>
    <: $array.reverse() :>

    <: $hash.keys().join(", ") :>
    <: $hash.values().join(", ") :>
    <: for $hash.kv() -> $pair { :>
        <: # $pair is a pair type with key and value fields -:>
        <: $pair.key :> = <: $pair.value :>
    <: } :>

Note that you must use C<()> in order to invoke methods.

=head2 Template inclusion

Template inclusion is a traditional way to extend templates.

    : include "foo.tx"
    : include "foo.tx" { var1 => value1, var2 => value2, ... }

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
with block modifiers.

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

Note that return values of macros are what their routines render.
That is, macros themselves output nothing.

=head2 Comments

    :# this is a comment
    <:
      # this is also a comment
      $var
    :>

=head1 SEE ALSO

L<Text::Xslate>

=cut
