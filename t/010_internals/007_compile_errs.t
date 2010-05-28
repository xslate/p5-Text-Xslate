#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Parser;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <:= $foo $bar :> world!
T
};
like $@, qr/Parser/;
like $@, qr/\$foo/;
like $@, qr/\$bar/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <:= xyzzy :> world!
T
};
like $@, qr/\b xyzzy \b/xms;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: if $lang { :> world!
T
};
like $@, qr/Parser/;
like $@, qr/Expected '}'/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: } :> world!
T
};
like $@, qr/Parser/;
like $@, qr/near '}'/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: if $foo { ; } } :> world!
T
};
like $@, qr/Parser/;
like $@, qr/near '}'/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: $foo <> $bar :> world!
T
};
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> ($var { ; }
T
};
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> $var) { ; }
T
};
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> ($x $y) { ; }
T
};
like $@, qr/Parser/;

foreach my $assign(qw(= += -= *= /= %= ~= &&= ||= //=)) {
    eval {
        Text::Xslate::Compiler->new->compile(<<"T");
        Hello, <: \$foo $assign 42 :> world!
T
    };
    like $@, qr/Parser/, "assignment ($assign)";
    like $@, qr/\Q$assign/;
    like $@, qr/\$foo/;
}

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: foo() :> world!
T
};
like $@, qr/Compiler/;
like $@, qr/\b foo \b/xms;

done_testing;
