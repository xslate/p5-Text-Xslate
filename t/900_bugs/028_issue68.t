#!/usr/bin/env perl
# https://github.com/xslate/p5-Text-Xslate/issues/68
# "Logic for constant folding unary ops isn't quite right"
use strict;
use warnings;
use Test::More;

use Text::Xslate;

    my $tx = Text::Xslate->new(cache => 0);
{
    my $warnings = '';
    local $SIG{__WARN__} = sub { $warnings .= $_[0] };
    my $result = $tx->render_string(': -(1 + $a)', { a => 2 });
    is($result, "-3");
    is($warnings, '');
}

done_testing;
