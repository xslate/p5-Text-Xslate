package Text::Xslate::Syntax::Kolon;
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
        syntax => 'Kolon', # optional
    );

    print $tx->render_string(
        'Hello, <: $dialect :> world!',
        { dialect => 'Kolon' }
    );

=head1 DESCRIPTION

Kolon is the default syntax, using C<< <: ... :> >> tags and C<< : ... >> line code. In this syntax all the features in Xslate are available.

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

    : nil   # as undef, indicating "nothing"
    : true  # as the integer 1
    : false # as the integer 0

String:

    : "foo\n" # the same as perl
    : 'foo\n' # the same as perl

Number:

    : 42
    : 3.14
    : 0xFF   # hex
    : 0777   # octal
    : 0b1010 # binary

Array:

    : for [1, 2, 3] -> $i { ... }

Hash:

    : foo({ foo => "bar" })

Note that C<{ ... }> is always parsed as hash literals, so you need not
to use prefix:<+> as Perl sometimes requires:

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
relational operators are numerical.

Arithmetic operators (C<< + - * / % min max >>):

    : $var * 10_000
    : ($var % 10) == 0
    : 10 min 20 min 30 # 10
    : 10 max 20 max 30 # 30

Bitwise operators (C<< prefix:<+^> +& +| +^ >>)

    : 0x1010 +| 0x3200 # bitwise or:  0x3210
    : 0x1010 +& 0x3200 # bitwise and: 0x1000
    : 0x1010 +^ 0x3200 # bitwise xor: 0x0210
    : +^0x1010         # bitwise neg: 0xFFFFEFEF (on 32 bit system)

Logical operators (C<< ! && || // not and or >>)

    : $var >= 0 && $var <= 10 ? "ok" : "too smaller or too larger"
    : $var // "foo" # as a default value

String operators (C<< ~ >>)

    : "[" ~ $var ~ "]" # concatenation

The operator precedence is very like Perl's:

    . () []
    prefix:<!> prefix:<+> prefix:<-> prefix:<+^>
    * / % x +&
    + - ~ +| +^
    prefix:<defined>
    < <= > >=
    == !=
    |
    &&
    || // min max
    ?:
    not
    and
    or

=head2 Constants (or binding)

You can define lexical constants with C<constant>, which requires a bare word,
and C<my>, which requires a variable name.

    : constant FOO = 42;
    : my      $foo = 42;

These two statements has the same semantics, so you cannot modify C<$foo>.

    : my $foo = 42; $foo = 3.14; # compile error!

=head2 Loops

There is C<for> loops that are like Perl's C<foreach>.

    : # iterate over an ARRAY reference
    : for $data -> $item {
        [<: $item.field :>]
    : }

    : # iterate over a HASH reference
    : # You must specify how to iterate it (.keys(), .values() or .kv())
    : for $data.keys() -> $key {
        <: $key :>=<: $data[$key] :>
    : }

And the C<for> statement can take C<else> block:

    : for $data -> $item {
        [<: $item.field :>]
    : }
    : else {
        Nothing in data
    : }

The C<else> block is executed if I<$data> is an empty array or nil.

You can get the iterator index in C<for> statements as C<$~ITERATOR_VAR>:

    : for $data -> $item {
        : if ($~item % 2) == 0 {
            Even (0, 2, 4, ...)
        : }
        : else {
            Odd (1, 3, 5, ...)
        : }
    : }

C<$~ITERATOR_VAR> is a pseudo object, so you can access its elements
via the dot-name syntax.

    : for $data -> $i {
        : $~i       # 0-origin iterator index (0, 1, 2, ...)
        : $~i.index # the same as $~i
        : $~i.count # the same as $~i + 1

        : if ($~i.index % 2) == 0 {
            even
        : }
        : else {
            odd
        : }
        : $~i.cycle("even", "odd") # => "even" -> "odd" -> "even" -> "odd" ...
    : }

Supported iterator elements are C<index :Int>, C<count :Int>,
C<body : ArrayRef>, C<size : Int>, C<max_index :Int>, C<is_first :Bool>,
C<is_last :Bool>, C<peek_next :Any>, C<peek_prev :Any>, C<cycle(...) :Any>.

C<while> loops are also supported in the same semantics as Perl's:

    : # $obj might be an iteratable object
    : while $dbh.fetch() -> $item {
        [<: $item.field :>]
    : }

C<< while defined expr -> $item >> is interpreted as
C<< while defined(my $item = expr) >> for convenience.

    : while defined $dbh.fetch() -> $item {
        [<: $item # $item can be false-but-defined :>]
    : }

Loop control statements, namely C<next> and C<last>, are also supported
in both C<for> and C<while> loops.

    : for $data -> $item {
        : last if $item == 42
        ...
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
    :   when ["bar", "baz" ] {
            it is either bar or baz.
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
            it is either bar or baz.
    :   }
    : }

=head2 Functions and filters

You can register functions via C<function> or C<module> options for
C<< Text::Xslate->new() >>.

Once you have registered functions, you can call them with the C<()> operator.
C<< infix:<|> >> is also supported as a syntactic sugar to C<()>.

    : f()        # without args
    : f(1, 2, 3) # with args
    : 42 | f     # the same as f(42)

Functions are just Perl's subroutines, so you can define dynamic functions
(a.k.a. dynamic filters), which is a subroutine that returns another subroutine:

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
    : $value | indent("> ") # Template-Toolkit like
    : indent("> ")($value)  # This is also valid

There are several builtin functions, which you cannot redefine:

    : $var | mark_raw   # marks it as a raw string
    : $var | raw        # synonym to mark_raw
    : $var | unmark_raw # removes "raw" marker from it
    : $var | html       # does html-escape to it and marks it as raw
    : $var | dump       # dumps it with Data::Dumper

Note that you should not use C<mark_raw> in templates because it can make security
hole easily just like as type casts in C. If you want to generate HTML components
dynamically, e.g. by HTML form builders, application code should be responsible
to make strings as marked C<raw>.

=head2 Methods

When I<$var> is an object instance, you can call its methods with the dot
operator.

    <: $var.method() :>
    <: $var.method(1, 2, 3) :>
    <: $var.method( foo => [ 1, 2, 3 ] ) :>

There is an autoboxing mechanism that provides primitive types with builtin
methods. See L<Text::Xslate::Manual::Builtin> for details.

You can define more primitive methods with the C<function> option. See L<Text::Xslate>.

=head2 Template inclusion

Template inclusion is a traditional way to extend templates.

    : include "foo.tx";
    : include "foo.tx" { var1 => value1, var2 => value2, ... };
    : include "foo.tx" {$vars}; # use $vars as the params

As C<cascade> does, C<include> allows barewords:

    : include foo      # the same as 'foo.tx'
    : include foo::bar # the same as 'foo/bar.tx'

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
        My template body!
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

In fact, you can omit the base template, and components
can include any macros.

Given a file F<common.tx>

    : macro hello -> $lang {
        Hello, <: $lang :> world!
    : }

    : around title -> {
        --------------
        : super
        --------------
    : }

The main template:

    : cascade with common

    : block title -> {
        Hello, world!
    : }
    : hello("Xslate")

Output:

        --------------
        Hello, world!
        --------------
    Hello, Xslate world!

There is a limitation that you cannot pass variables to the C<cascade> keyword,
because template cascading is statically processed.

=head2 Macro blocks

Macros are supported, which are called in the same way as functions and
return a C<raw> string. Macros returns what their bodies render, so
they cannot return references nor objects including other macros.

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

If you want to html-escape the return values of macros, you can use
C<unmark_raw> to remove C<raw-ness> from the values.

    : macro em -> $s {
    <em><: $s :></em>
    : }
    : em("foo")               # renders "<em>foo</em>"
    : em("foo") | unmark_raw  # renders "&lt;em&gt;foo&lt;em&gt;"

Because macros are first-class objects, you can bind them to symbols.

    <: macro foo -> { "foo" }
       macro bar -> { "bar" }
       my $dispatcher = {
           foo => foo,
           bar => bar,
       }; -:>
    : $dispatcher{$key}()

Anonymous macros are also supported, although they can return
only strings. They might be useful for callbacks to high-level
functions or methods.

    <: -> $x, $y { $x + $y }(1, 2) # => 3 :>

The C<block> keyword is used to make a group of template code,
and you can apply filters to that block with C<< infix:<|> >>.
Here is an example to embed HTML source code into templates.

Template:

    : block source | unmark_raw -> {
        <em>Hello, world!</em>
    : }

Output:

    &lt;em&gt;Hello, world!&lt;/em&gt;

See also L<Text::Xslate::Manual::Cookbook/"Using FillInForm"> for
another example to use this block filter syntax.

Note that closures are not supported.

=head2 Chomping newlines

You can add C<-> to the immediate start or end of a directive tag to control the newline chomping options to keep the output clean. The starting C<-> removes leading newlines and the ending C<-> removes trailing ones.

=head2 Special keywords

There are special keywords:

=over

=item __FILE__

Indicates the current file name. Equivalent to C<< Text::Xslate->current_file >>.

=item __LINE__

Indicates the current line number. Equivalent to C<< Text::Xslate->current_line >>.

=item __ROOT__

Means the root of the parameters. Equivalent to C<< Text::Xslate->current_vars >>.

=back

=head2 Comments

Comments start from C<#> to a new line or semicolon.

    :# this is a comment
    <:
      # this is also a comment
      $foo # $foo is rendered
    :>

    <: $bar # this is ok :>
    <: # this is comment; $baz # $baz is rendered :>

=head1 SEE ALSO

L<Text::Xslate>

=cut
