#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use warnings FATAL => 'all';

eval {
    Text::Xslate->render(undef, {});
};
like $@, qr/Invalid xslate instance/;

eval {
    Text::Xslate->new(foobar => 1);
};
like $@, qr/Unknown option/, 'unknown options';
like $@, qr/\b foobar \b/xms;

for my $builtin qw(raw html dump) {
    eval {
        Text::Xslate->new(function => { $builtin => sub {} });
    };
    like $@, qr/cannot redefine/, "cannot redefined $builtin";
    like $@, qr/\b $builtin \b/xms;
}

my $tx = Text::Xslate->new();

eval {
    $tx->render(undef, []);
};
like $@, qr/must be a HASH reference/;

eval {
    $tx->render(undef, {});
};
ok $@, 'render() requires two arguments';

eval {
    $tx->render();
};
ok $@, 'render() without argument';

eval {
    $tx->new();
};
ok $@, '$txinstance->new()';


# EscapedString

eval {
    Text::Xslate::EscapedString->new();
};
ok $@, $@;

eval {
    Text::Xslate::EscapedString->new("")->new("");
};
like $@, qr/You cannot call/;

eval {
    Text::Xslate::EscapedString->as_string();
};
like $@, qr/You cannot call/;

eval {
    package MyEscapedString;
    our @ISA = qw(Text::Xslate::EscapedString);

    __PACKAGE__->new("foo");
};
ok $@, qr/cannot extend Text::Xslate::EscapedString/;

done_testing;
