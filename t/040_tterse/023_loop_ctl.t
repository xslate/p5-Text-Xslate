#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my %vpath = (
);

my $tx = Text::Xslate->new(
    syntax => 'TTerse',
    cache => 0,
    path => \%vpath,
    verbose => 2,
    warn_handler => sub { die @_ },
);

note 'for';
is $tx->render_string(<<'T'), <<'X' or die;
%% for it in [42, 43, 44]
    %% last if it == 43
    * [% it %]
%% end
T
    * 42
X

is $tx->render_string(<<'T'), <<'X' or die;
%% for it in [42, 43, 44]
    %% NEXT if it == 43
    * [% it %]
%% END
T
    * 42
    * 44
X

note 'while';
my $iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
%% while it = iter()
    %% NEXT if it == 43
    * [% it %]
%% END
T
    * 42
    * 44
X

$iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
%% while it = iter()
    %% LAST if it == 43
    * [% it %]
%% END
T
    * 42
X

$iter = do{ my @a = (42, 43, 44); sub { shift @a } };
is $tx->render_string(<<'T', { iter => $iter }), <<'X';
%% while it = iter()
    * [% it %]
    %% LAST if it == 43
%% END
T
    * 42
    * 43
X

done_testing;
