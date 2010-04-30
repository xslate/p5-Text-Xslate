#!perl -w

use strict;
use Test::More;

use Text::Xslate;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <:= $foo $bar :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;
like $@, qr/\$foo/;
like $@, qr/\$bar/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <:= xyzzy :> world!
T

    $tx->render({});
};
like $@, qr/\b xyzzy \b/xms;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: if $lang { :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;
like $@, qr/Expected '}'/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: } :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;
like $@, qr/near '}'/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: if $foo { ; } } :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;
like $@, qr/near '}'/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: $foo <> $bar :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: $foo = 42 :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: $foo = 42 :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;

# success
my $out = eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <:= $lang :> world!
T

    $tx->render({lang => "Xslate"});
};
is $@, '', "success";
is $out, "    Hello, Xslate world!\n";

done_testing;
