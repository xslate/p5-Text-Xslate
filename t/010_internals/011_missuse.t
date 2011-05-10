#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use warnings FATAL => 'all';

eval {
    Text::Xslate->render('<string>', {});
};
like $@, qr/Invalid xslate instance/;

eval {
    Text::Xslate->new(foobar => 1);
};
like $@, qr/Unknown option/, 'unknown options';
like $@, qr/\b foobar \b/xms;


my $tx = Text::Xslate->new(cache => 0);

eval {
    $tx->render('<string>', []);
};
like $@, qr/must be a HASH reference/;

eval {
    $tx->render('<string>', {});
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

# break internals to ensure robustness

$tx->{template} = [];
eval {
    $tx->render('foo.tx');
};
like $@, qr/Cannot load template/;
like $@, qr/\b foo\.tx \b/xms;

$tx->{template} = { 'foo.tx' => undef };
eval {
    $tx->render('foo.tx');
};
like $@, qr/Cannot load template/;
like $@, qr/\b foo\.tx \b/xms;

$tx->{template} = { 'foo.tx' => [] };
eval {
    $tx->render('foo.tx');
};
like $@, qr/Cannot load template/;
like $@, qr/\b foo\.tx \b/xms;

# Type::Raw

eval {
    Text::Xslate::Type::Raw->new();
};
ok $@, $@;

eval {
    Text::Xslate::Type::Raw->new("")->new("");
};
like $@, qr/You cannot call/;

eval {
    Text::Xslate::Type::Raw->as_string();
};
like $@, qr/You cannot call/;

eval {
    package MyType::Raw;
    our @ISA = qw(Text::Xslate::Type::Raw);

    __PACKAGE__->new("foo");
};
like $@, qr/cannot extend Text::Xslate::Type::Raw/;

done_testing;
