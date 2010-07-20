#!perl -w
use strict;
use Benchmark qw(:all);
use Storable  qw(dclone);

use Text::Xslate::Compiler;

my $p = Text::Xslate::Compiler->new();

cmpthese -1, {
    dclone => sub { dclone($p) },
    new    => sub { Text::Xslate::Compiler->new() },
};
