#!perl -w
use 5.010;
use strict;
{
    package Base;
    use Any::Moose;

    sub foo { say "Base::foo" }

    package Role;
    use Any::Moose '::Role';

    before foo => sub { say "Role::before" };
    after  foo => sub { say "Role::after" };

    package Derived;
    use Any::Moose;
    extends 'Base';
    with 'Role';

    before foo => sub { say "Derived::before" };
    after  foo => sub { say "Derived::after" };
}

Derived->foo;
