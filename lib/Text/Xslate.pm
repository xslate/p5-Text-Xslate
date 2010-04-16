package Text::Xslate;

use 5.010_000;
use strict;

our $VERSION = '0.001';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.001.

=head1 SYNOPSIS

    use Text::Xslate;
    use Text::Xslate::Compiler;

    my $template = q{
        <h1><?= $title ?></h1>
        <ul>
        ? for $books ->($book) {
            <li><?= $book.title ?></li>
        ? } # for
        </ul>
    };

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            { title => 'River out of Eden'     },
            { title => 'Beautiful code'        },
        ],
    );

    # XXX: the interface will be changed!
    my $tx = Text::Xslate::Compiler->new()->compile_str($template);

    print $tx->render(\%vars);

=head1 DESCRIPTION

Text::Xslate is an template engine.

This is an B<alpha> software. Don't use this yet.

=head1 INTERFACE

TODO

=head1 TEMPLATE SYNTAX

TODO

=head1 PERFORMANCE

TODO

=head1 TODO

=over

=item *

Debuggability improvement

=item *

Template inheritance (like Text::MicroTemplate::Extended)

=item *

String filters (like Template-Toolkit)

=item *

Template inclusion

=item *

The given-when statement

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
