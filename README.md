[![Build Status](https://travis-ci.org/xslate/p5-Text-Xslate.svg?branch=master)](https://travis-ci.org/xslate/p5-Text-Xslate)
# NAME

Text::Xslate - Scalable template engine for Perl5

# VERSION

This document describes Text::Xslate version v3.5.6.

# SYNOPSIS

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

# DESCRIPTION

**Xslate** is a template engine, tuned for persistent applications,
safe as an HTML generator, and with rich features.

There are a lot of template engines in CPAN, for example Template-Toolkit,
Text::MicroTemplate, HTML::Template, and so on, but all of them have
some weak points: a full-featured template engine may be slow,
while a fast template engine may be too simple to use. This is why Xslate is
developed, which is the best template engine for web applications.

The concept of Xslate is strongly influenced by Text::MicroTemplate
and Template-Toolkit 2, but the central philosophy of Xslate is different
from them. That is, the philosophy is **sandboxing** that the template logic
should not have no access outside the template beyond your permission.

Other remarkable features are as follows:

## Features

### High performance

This engine introduces the virtual machine paradigm. Templates are
compiled into intermediate code, and then executed by the virtual machine,
which is highly optimized for rendering templates. Thus, Xslate is
much faster than any other template engines.

The template roundup project by Sam Graham shows Text::Xslate got
amazingly high scores in _instance\_reuse_ condition
(i.e. for persistent applications).

- The template roundup project

    [http://illusori.co.uk/projects/Template-Roundup/](http://illusori.co.uk/projects/Template-Roundup/)

- Perl Template Roundup October 2010 Performance vs Variant Report: instance\_reuse

    [http://illusori.co.uk/projects/Template-Roundup/201010/performance\_vs\_variant\_by\_feature\_for\_instance\_reuse.html](http://illusori.co.uk/projects/Template-Roundup/201010/performance_vs_variant_by_feature_for_instance_reuse.html)

There are also benchmarks in `benchmark/` directory in the Xslate distribution.

### Smart escaping for HTML metacharacters

Xslate employs the **smart escaping strategy**, where a template engine
escapes all the HTML metacharacters in template expressions unless users
mark values as **raw**.
That is, the output is unlikely to prone to XSS.

### Template cascading

Xslate supports the **template cascading**, which allows you to extend
templates with block modifiers. It is like a traditional template inclusion,
but is more powerful.

This mechanism is also called as template inheritance.

### Easiness to enhance

Xslate is ready to enhance. You can add functions and methods to the template
engine and even add a new syntax via extending the parser.

# INTERFACE

## Methods

### **Text::Xslate->new(%options)**

Creates a new Xslate template engine with options. You can reuse this instance
for multiple calls to `render()`.

Possible options are:

- `path => \@path // ['.']`

    Specifies the include paths, which may be directory names or virtual paths,
    i.e. HASH references which contain `$file_name => $content` pairs.

    Note that if you use taint mode (`-T`), you have to give absolute paths
    to `path` and `cache_dir`. Otherwise you'll get errors because they
    depend on the current working directory which might not be secure.

- `cache => $level // 1`

    Sets the cache level.

    If `$level == 1` (default), Xslate caches compiled templates on the disk, and
    checks the freshness of the original templates every time.

    If `$level >= 2`, caches will be created but the freshness
    will not be checked.

    `$level == 0` uses no caches, which is provided for testing.

- `cache_dir => $dir // "$ENV{HOME}/.xslate_cache"`

    Specifies the directory used for caches. If `$ENV{HOME}` doesn't exist,
    `File::Spec->tmpdir` will be used.

    You **should** specify this option for productions to avoid conflicts of
    template names.

- `function => \%functions`

    Specifies a function map which contains name-coderef pairs.
    A function `f` may be called as `f($arg)` or `$arg | f` in templates.

    Note that these registered functions have to return a **text string**,
    not a binary string unless you want to handle bytes in whole templates.
    Make sure what you want to use returns either a text string or a binary
    string.

    For example, some methods of `Time::Piece` might return a binary string
    which is encoded in UTF-8, so you'll want to decode their values.

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

    Built-in functions are described in [Text::Xslate::Manual::Builtin](https://metacpan.org/pod/Text::Xslate::Manual::Builtin).

- `module => [$module => ?\@import_args, ...]`

    Imports functions from _$module_, which may be a function-based or bridge module.
    Optional _@import\_args_ are passed to `import` as `$module->import(@import_args)`.

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

    Because you can use function-based modules with the `module` option, and
    also can invoke any object methods in templates, Xslate doesn't require
    specific namespaces for plugins.

- `html_builder_module => [$module => ?\@import_args, ...]`

    Imports functions from _$module_, wrapping each function with `html_builder()`.

- `input_layer => $perliolayers // ':utf8'`

    Specifies PerlIO layers to open template files.

- `verbose => $level // 1`

    Specifies the verbose level.

    If `$level == 0`, all the possible errors will be ignored.

    If `$level >= 1` (default), trivial errors (e.g. to print nil) will be ignored,
    but severe errors (e.g. for a method to throw the error) will be warned.

    If `$level >= 2`, all the possible errors will be warned.

- `suffix => $ext // '.tx'`

    Specify the template suffix, which is used for `cascade` and `include`
    in Kolon.

    Note that this is used for static name resolution. That is, the compiler
    uses it but the runtime engine doesn't.

- `syntax => $name // 'Kolon'`

    Specifies the template syntax you want to use.

    _$name_ may be a short name (e.g. `Kolon`), or a fully qualified name
    (e.g. `Text::Xslate::Syntax::Kolon`).

    This option is passed to the compiler directly.

- `type => $type // 'html'`

    Specifies the output content type. If _$type_ is `html` or `xml`,
    smart escaping is applied to template expressions. That is,
    they are interpolated via the `html_escape` filter.
    If _$type_ is `text` smart escaping is not applied so that it is
    suitable for plain texts like e-mails.

    _$type_ may be **html**, **xml** (identical to `html`), and **text**.

    This option is passed to the compiler directly.

- `line_start => $token // $parser_defined_str`

    Specify the token to start line code as a string, which `quotemeta` will be applied to. If you give `undef`, the line code style is disabled.

    This option is passed to the parser via the compiler.

- `tag_start => $str // $parser_defined_str`

    Specify the token to start inline code as a string, which `quotemeta` will be applied to.

    This option is passed to the parser via the compiler.

- `tag_end => $str // $parser_defined_str`

    Specify the token to end inline code as a string, which `quotemeta` will be applied to.

    This option is passed to the parser via the compiler.

- `header => \@template_files`

    Specify the header template files, which are inserted to the head of each template.

    This option is passed to the compiler.

- `footer => \@template_files`

    Specify the footer template files, which are inserted to the foot of each template.

    This option is passed to the compiler.

- `warn_handler => \&cb`

    Specify the callback _&cb_ which is called on warnings.

- `die_handler => \&cb`

    Specify the callback _&cb_ which is called on fatal errors.

- `pre_process_handler => \&cb`

    Specify the callback _&cb_ which is called after templates are loaded from the disk
    in order to pre-process template.

    For example:

        # Remove whitespace from templates
        my $tx = Text::Xslate->new(
            pre_process_handler => sub {
                my $text = shift;
                $text=~s/\s+//g;
                return $text;
            }
        );

    The first argument is the template text string, which can be both **text strings** and `byte strings`.

    This filter is applied only to files, not a string template for `render_string`.

### **$tx->render($file, \\%vars) :Str**

Renders a template file with given variables, and returns the result.
_\\%vars_ is optional.

Note that _$file_ may be cached according to the cache level.

### **$tx->render\_string($string, \\%vars) :Str**

Renders a template string with given variables, and returns the result.
_\\%vars_ is optional.

Note that _$string_ is never cached, so this method should be avoided in
production environment. If you want in-memory templates, consider the _path_
option for HASH references which are cached as you expect:

    my %vpath = (
        'hello.tx' => 'Hello, <: $lang :> world!',
    );

    my $tx = Text::Xslate->new( path => \%vpath );
    print $tx->render('hello.tx', { lang => 'Xslate' });

Note that _$string_ must be a text string, not a binary string.

### **$tx->load\_file($file) :Void**

Loads _$file_ into memory for following `render()`.
Compiles and saves it as disk caches if needed.

### **Text::Xslate->current\_engine :XslateEngine**

Returns the current Xslate engine while executing. Otherwise returns `undef`.
This method is significant when it is called by template functions and methods.

### **Text::Xslate->current\_vars :HashRef**

Returns the current variable table, namely the second argument of
`render()` while executing. Otherwise returns `undef`.

### **Text::Xslate->current\_file :Str**

Returns the current file name while executing. Otherwise returns `undef`.
This method is significant when it is called by template functions and methods.

### **Text::Xslate->current\_line :Int**

Returns the current line number while executing. Otherwise returns `undef`.
This method is significant when it is called by template functions and methods.

### **Text::Xslate->print(...) :Void**

Adds the argument into the output buffer. This method is available on executing.

### **$tx->validate($file) :Void**

Checks whether the syntax of _$file_ is valid or invalid as Xslate.
If it detects the invalid factor, this method throws the exception.

## Exportable functions

### `mark_raw($str :Str) :RawStr`

Marks _$str_ as raw, so that the content of _$str_ will be rendered as is,
so you have to escape these strings by yourself.

For example:

    use Text::Xslate qw( mark_raw );

    my $tx   = Text::Xslate->new();
    my $tmpl = 'Mailaddress: <: $email :>';
    my %vars = (
        email => mark_raw('Foo &lt;foo at example.com&gt;'),
    );
    print $tx->render_string($tmpl, \%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

This function is available in templates as the `mark_raw` filter, although
the use of it is strongly discouraged.

### `unmark_raw($str :Str) :Str`

Clears the raw marker from _$str_, so that the content of _$str_ will
be escaped before rendered.

This function is available in templates as the `unmark_raw` filter.

### `html_escape($str :Str) :RawStr`

Escapes HTML meta characters in _$str_, and returns it as a raw string (see above).
If _$str_ is already a raw string, it returns _$str_ as is.

By default, this function will automatically be applied to all template
expressions.

This function is available in templates as the `html` filter, but you're better
off using `unmark_raw` to ensure that expressions are html-escaped.

### `uri_escape($str :Str) :Str`

Escapes URI unsafe characters in _$str_, and returns it.

This function is available in templates as the `uri` filter.

### `html_builder { block } | \&function :CodeRef`

Wraps a block or _&function_ with `mark_raw` so that the new subroutine
will return a raw string.

This function is used to tell the xslate engine that _&function_ is an
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

See also [Text::Xslate::Manual::Cookbook](https://metacpan.org/pod/Text::Xslate::Manual::Cookbook).

## Command line interface

The `xslate(1)` command is provided as a CLI to the Text::Xslate module,
which is used to process directory trees or to evaluate one liners.
For example:

    $ xslate -Dname=value -o dest_path src_path

    $ xslate -e 'Hello, <: $ARGV[0] :> wolrd!' Xslate
    $ xslate -s TTerse -e 'Hello, [% ARGV.0 %] world!' TTerse

See [xslate(1)](http://man.he.net/man1/xslate) for details.

# TEMPLATE SYNTAX

There are multiple template syntaxes available in Xslate.

- Kolon

    **Kolon** is the default syntax, using `<: ... :>` inline code and
    `: ...` line code, which is explained in [Text::Xslate::Syntax::Kolon](https://metacpan.org/pod/Text::Xslate::Syntax::Kolon).

- Metakolon

    **Metakolon** is the same as Kolon except for using `[% ... %]` inline code and
    `%% ...` line code, instead of `<: ... :>` and `: ...`.

- TTerse

    **TTerse** is a syntax that is a subset of Template-Toolkit 2 (and partially TT3),
    which is explained in [Text::Xslate::Syntax::TTerse](https://metacpan.org/pod/Text::Xslate::Syntax::TTerse).

- HTMLTemplate

    There's HTML::Template compatible layers in CPAN.

    [Text::Xslate::Syntax::HTMLTemplate](https://metacpan.org/pod/Text::Xslate::Syntax::HTMLTemplate) is a syntax for HTML::Template.

    [HTML::Template::Parser](https://metacpan.org/pod/HTML::Template::Parser) is a converter from HTML::Template to Text::Xslate.

# NOTES

There are common notes in Xslate.

## Nil/undef handling

Note that nil (i.e. `undef` in Perl) handling is different from Perl's.
Basically it does nothing, but `verbose => 2` will produce warnings on it.

- to print

    Prints nothing.

- to access fields

    Returns nil. That is, `nil.foo.bar.baz` produces nil.

- to invoke methods

    Returns nil. That is, `nil.foo().bar().baz()` produces nil.

- to iterate

    Dealt as an empty array.

- equality

    `$var == nil` returns true if and only if _$var_ is nil.

# DEPENDENCIES

Perl 5.8.1 or later.

If you have a C compiler, the XS backend will be used. Otherwise the pure Perl
backend will be used.

# TODO

- Context controls. e.g. `<: [ $foo->bar @list ] :>`.
- Augment modifiers.
- Default arguments and named arguments for macros.
- External macros.

    Just idea: in the new macro concept, macros and external templates will be
    the same in internals:

        : macro foo($lang) { "Hello, " ~ $lang ~ " world!" }
        : include foo { lang => 'Xslate' }
        : # => 'Hello, Xslate world!'

        : extern bar 'my/bar.tx';     # 'extern bar $file' is ok
        : bar( value => 42 );         # calls an external template
        : include bar { value => 42 } # ditto

- A "too-safe" HTML escaping filter which escape all the symbolic characters

# RESOURCES

PROJECT HOME: [https://github.com/xslate/](https://github.com/xslate/)

REPOSITORY: [https://github.com/xslate/p5-Text-Xslate/](https://github.com/xslate/p5-Text-Xslate/)

# BUGS

Please report issues at [https://github.com/xslate/p5-Text-Xslate/issues](https://github.com/xslate/p5-Text-Xslate/issues).
Patches are always welcome.

# SEE ALSO

Documents:

[Text::Xslate::Manual](https://metacpan.org/pod/Text::Xslate::Manual)

Xslate template syntaxes:

[Text::Xslate::Syntax::Kolon](https://metacpan.org/pod/Text::Xslate::Syntax::Kolon)

[Text::Xslate::Syntax::Metakolon](https://metacpan.org/pod/Text::Xslate::Syntax::Metakolon)

[Text::Xslate::Syntax::TTerse](https://metacpan.org/pod/Text::Xslate::Syntax::TTerse)

Xslate command:

[xslate](https://metacpan.org/pod/xslate)

Other template modules that Xslate has been influenced by:

[Text::MicroTemplate](https://metacpan.org/pod/Text::MicroTemplate)

[Text::MicroTemplate::Extended](https://metacpan.org/pod/Text::MicroTemplate::Extended)

[Text::ClearSilver](https://metacpan.org/pod/Text::ClearSilver)

[Template](https://metacpan.org/pod/Template) (Template::Toolkit)

[HTML::Template](https://metacpan.org/pod/HTML::Template)

[HTML::Template::Pro](https://metacpan.org/pod/HTML::Template::Pro)

[Template::Alloy](https://metacpan.org/pod/Template::Alloy)

[Template::Sandbox](https://metacpan.org/pod/Template::Sandbox)

Benchmarks:

[Template::Benchmark](https://metacpan.org/pod/Template::Benchmark)

Papers:

[http://www.cs.usfca.edu/~parrt/papers/mvc.templates.pdf](http://www.cs.usfca.edu/~parrt/papers/mvc.templates.pdf) -  Enforcing Strict Model-View Separation in Template Engines

# ACKNOWLEDGEMENT

Thanks to lestrrat for the suggestion to the interface of `render()`,
the contribution of Text::Xslate::Runner (was App::Xslate), and a lot of
suggestions.

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug finding.

Thanks to gardejo for the proposal to the name **template cascading**.

Thanks to makamaka for the contribution of Text::Xslate::PP.

Thanks to jjn1056 to the concept of template overlay (now implemented as `cascade with ...`).

Thanks to typester for the various inspirations.

Thanks to clouder for the patch of adding `AND` and `OR` to TTerse.

Thanks to punytan for the documentation improvement.

Thanks to chiba for the bug reports and patches.

Thanks to turugina for the patch to fix Win32 problems

Thanks to Sam Graham for the bug reports.

Thanks to Mons Anderson for the bug reports and patches.

Thanks to hirose31 for the feature requests and bug reports.

Thanks to c9s for the contribution of the documents.

Thanks to shiba\_yu36 for the bug reports.

Thanks to kane46taka for the bug reports.

Thanks to cho45 for the bug reports.

Thanks to shmorimo for the bug reports.

Thanks to ueda for the suggestions.

# AUTHOR

Fuji, Goro (gfx) <gfuji@cpan.org>.

Makamaka Hannyaharamitu (makamaka) (Text::Xslate::PP)

Maki, Daisuke (lestrrat) (Text::Xslate::Runner)

# LICENSE AND COPYRIGHT

Copyright (c) 2010-2013, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
