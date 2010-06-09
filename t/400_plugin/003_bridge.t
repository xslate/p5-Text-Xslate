#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use lib 't/lib';

{
    package MyBridge;
    use parent qw(Text::Xslate::Bridge);

    __PACKAGE__->bridge(
        scalar => { foo => sub { 'scalar foo' } },
        array  => { foo => sub { 'array foo'  }, size => sub { 42 } },
        hash   => { foo => sub { 'hash foo'   } },
    );
}

my $tx = Text::Xslate->new(
    module => [qw(MyBridge)],
);

is $tx->render_string('<: "xx".foo() :>'), 'scalar foo';
is $tx->render_string('<: [42].foo() :>'), 'array foo';
is $tx->render_string('<: {  }.foo() :>'), 'hash foo';

is $tx->render_string('<: [].size() :>'), '42';

$tx = Text::Xslate->new(
    module => ['MyBridge' => [-exclude => [qw(array::size)]] ],
);

is $tx->render_string('<: [].foo() :>'), 'array foo';
is $tx->render_string('<: [].size() :>'), '0';

$tx = Text::Xslate->new(
    module => [qw(MyBridge2)],
);

is $tx->render_string('<: "xx".foo() :>'), 'scalar bar';
is $tx->render_string('<: [42].foo() :>'), 'array bar';
is $tx->render_string('<: {  }.foo() :>'), 'hash bar';


done_testing;
