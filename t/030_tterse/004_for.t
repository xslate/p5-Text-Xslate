#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;
use Text::Xslate::Parser::TTerse;

my $tx = Text::Xslate::Compiler->new(
    parser => Text::Xslate::Parser::TTerse->new(),
);

my @data = (
    [<<'T', <<'X'],
[% lang %]
[% FOREACH type IN types -%]
* [% type %]
[% END -%]
END
T
Xslate
* Str
* Int
* Object
END
X
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        lang => 'Xslate',

        types => [qw(Str Int Object)],
    );
    is $x->render(\%vars), $out;
}

done_testing;
