package MyBridge2;
use strict;
use parent qw(Text::Xslate::Bridge);

__PACKAGE__->bridge(
    scalar => { bar => sub { 'scalar bar' } },
    array  => { bar => sub { 'array bar'  } },
    hash   => { bar => sub { 'hash bar'   } },
);


1;
