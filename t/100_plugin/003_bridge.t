#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use lib 't/lib';


sub verify_bridge2 {
    my $tx = shift;
    is $tx->render_string('<: "xx".bar() :>'), 'scalar bar';
    is $tx->render_string('<: [42].bar() :>'), 'array bar';
    is $tx->render_string('<: {  }.bar() :>'), 'hash bar';
}

sub verify_bridge1 {
    my $tx = shift;
    is $tx->render_string('<: "xx".foo() :>'), 'scalar foo';
    is $tx->render_string('<: [42].foo() :>'), 'array foo';
    is $tx->render_string('<: {  }.foo() :>'), 'hash foo';
    is $tx->render_string('<: "foo" | foo :>'), 'func foo';
    is $tx->render_string('<: [].size() :>'), '42';
}

{
    package MyBridge;
    use parent qw(Text::Xslate::Bridge);

    __PACKAGE__->bridge(
        scalar => { foo => sub { 'scalar foo' } },
        array  => { foo => sub { 'array foo'  }, size => sub { 42 } },
        hash   => { foo => sub { 'hash foo'   } },

        function => { foo => sub { 'func foo' } },
    );
}

my $tx = Text::Xslate->new(
    module => [qw(MyBridge)],
);

verify_bridge1( $tx );

$tx = Text::Xslate->new(
    module => ['MyBridge' => [-exclude => [qw(array::size)]] ],
);

is $tx->render_string('<: [].foo() :>'), 'array foo';
is $tx->render_string('<: [].size() :>'), '0';

$tx = Text::Xslate->new(
    module => [qw(MyBridge2)],
);

verify_bridge2( $tx );

$tx = Text::Xslate->new(
    module => [qw(MyBridge MyBridge2)],
);

verify_bridge1( $tx );
verify_bridge2( $tx );

done_testing;
