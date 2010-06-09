package MyBridge2;
use strict;
use parent qw(Text::Xslate::Bridge);

__PACKAGE__->bridge(
    scalar => { foo => sub { 'scalar bar' } },
    array  => { foo => sub { 'array bar'  } },
    hash   => { foo => sub { 'hash bar'   } },
);


1;
