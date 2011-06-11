#!perl -w
use strict;
use Test::More;
use Text::Xslate;

my $tx = Text::Xslate->new(
    syntax => 'TTerse',
);

is $tx->render_string(<<'T'), "1\n5\n";
[% __LINE__ ~ "\n";
   # 2
   # 3
   # 4
   __LINE__
%]
T

is $tx->render_string(<<'T'), "1\n5\n";
%%__LINE__ ~ "\n"
%% # 2
%% # 3
%% # 4
%% __LINE__ ~ "\n"
T

done_testing;

