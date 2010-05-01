#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Parser;

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

foreach my $assign(qw(= += -= *= /= %= ~= &&= ||= //=)) {
    eval {
        my $tx = Text::Xslate->new(string => <<"T");
        Hello, <: \$foo $assign 42 :> world!
T
    };
    like $@, qr/Parser/, "assignment ($assign)";
    like $@, qr/\Q$assign/;
    like $@, qr/\$foo/;
}

eval {
    my $tx = Text::Xslate->new(string => <<'T');
    Hello, <: foo() :> world!
T

    $tx->render({});
};
like $@, qr/Parser/;
like $@, qr/\b foo \b/xms;

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
