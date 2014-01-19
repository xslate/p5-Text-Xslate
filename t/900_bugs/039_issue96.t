#!perl
use strict;
use warnings;

use Test::More;

use Text::Xslate::Syntax::Kolon;

{
    my $content = <<'T';
: cascade bar {
:     hoge => 'fuga'
: }
T
    my $parser = Text::Xslate::Syntax::Kolon->new();

    local $/;
    $parser->parse($content);
}

pass;

done_testing;
