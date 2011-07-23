#!perl -w
# TODO
use strict;

use Text::Xslate;
use File::Slurp qw(slurp);
use HTML::Template::Parser;
use HTML::Template::Parser::TreeWriter::TextXslate::Metakolon;

my $htparser = HTML::Template::Parser->new();
my $ast      = $htparser->parse(slurp 'example/hello.tmpl');

my $writer = HTML::Template::Parser::TreeWriter::TextXslate::Metakolon->new;
my $source = $writer->write($ast);

my $tx = Text::Xslate->new(
    syntax => 'Metakolon',
    cache  => 0,
);

print $tx->render_string($source, { lang => 'HTML::Template' });

