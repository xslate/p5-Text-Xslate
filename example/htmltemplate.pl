#!perl -w
# TODO
use strict;

use Text::Xslate;

my $tx = Text::Xslate->new(
    syntax => 'HTMLTemplate',
    cache  => 0,
);

print $tx->render('example/hello.tmpl', { lang => 'HTML::Template' });

