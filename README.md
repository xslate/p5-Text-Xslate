# NAME [![Build Status](https://secure.travis-ci.org/xslate/p5-Text-Xslate.png)](http://travis-ci.org/xslate/p5-Text-Xslate)

Text::Xslate - Scalable template engine for Perl5

# SYNOPSIS

    use Text::Xslate;

    my $tx = Text::Xslate->new();

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            # ...
        ],
    );

    my $template = q{
    <h1><: $title :></h1>
    <ul>
    : for $books -> $book {
        <li><: $book.title :></li>
    : } # for
    </ul>
    };

    print $tx->render_string($template, \%vars);

# INSTALLATION

Install cpanm (App::cpanminus) and then run the following command to install
Xslate:

    $ cpanm Text::Xslate

If you get the distribution, unpack it and build it as per the usual:

    $ tar xzf Text-Xslate-{version}.tar.gz
    $ cd Text-Xslate-{version}
    $ perl Makefile.PL
    $ make && make test

Then install it:

    $ make install

If you want to install it from the repository, you must install authoring
tools.

    $ cpanm < author/requires.cpanm

# DOCUMENTATION

Text::Xslate documentation is available as in POD. So you can do:

    $ perldoc Text::Xslate

to read the documentation online with your favorite pager.

# RESOURCE

    web site:     http://xslate.org/
    repositories: http://github.com/xslate
    mailing list: http://groups.google.com/group/xslate
    irc         : irc://irc.perl.org/#xslate

# LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


# MAINTAINERS

 * [Fuji, Goro](https://github.com/gfx/)
 * [Daisuke Maki](https://github.com/lestrrat)
 * [Syohei Yoshida](https://github.com/syohex/)
 * [Tokuhiro Matsuno](https://github.com/tokuhirom/)
