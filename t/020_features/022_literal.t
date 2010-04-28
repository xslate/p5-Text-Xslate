#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<:= 1.23 :>',     1.23 ],
    ['<:= 1_23 :>',     1_23 ],
    ['<:= 1_23.1_2 :>', 1_23.1_2 ],
    ['<:= "\n\n" :>',     "\n\n" ],
    ['<:= "\r\r" :>',     "\r\r" ],
    ['<:= "\t\t" :>',     "\t\t" ],
    ['<:= "\"\"" :>',     "&quot;&quot;" ],
    ['<:= "\+\+" :>',     "\+\+" ],
    ['<:= "\\\\\\\\" :>',     "\\\\" ],
    ['<:= "<:$foo:>" :>', '&lt;:$foo:&gt;' ],
    [q{<:= '\n\n' :>}, '\n\n' ],
    [q{<:= '\\\\\\\\' :>}, '\\\\' ],
    [q{<:= '\'\'' :>}, '&#39;&#39;' ],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = ();
    is $x->render(\%vars), $out, $in;
}

done_testing;
