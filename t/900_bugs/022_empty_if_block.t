#!perl
use strict;
use warnings;
use Test::More;
use Text::Xslate;

my %vpath = (
    simple_if => <<'T',
%% IF hoge
%% ELSE;
%%    IF fuga
%%    ELSE
%%    END
%% END
hi
T

    declare_if => <<'T',
[% IF hoge %]
[% ELSE %]
[%    IF fuga %]
[%    ELSE %]
[%    END  %]
[%    SET hoge = fuga %]
[% END %]
hi
T

    problem_case => <<'T',
%% IF hogex
%% ELSE;
%%    IF fugax
%%    ELSE
%%    END
%%    SET hogex = fugax;
%% END
hi
T
);

my $xslate = Text::Xslate->new(
    syntax => 'TTerse',
    path => \%vpath,
    cache => 0,
);

ok $xslate->render('simple_if'), 'simple_if';
ok $xslate->render('declare_if'), 'declare_if';
ok $xslate->render('problem_case'), 'problem_case';

done_testing;

