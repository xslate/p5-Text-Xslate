#!perl -w
# recursive INCLUDE broke the stack frame
use strict;
use warnings;
use Test::More;

use Text::Xslate;

my %vpath = (
    main => <<'T',
[% FOR entry IN entries -%]
    + [% entry.name %]
    [% INCLUDE 'entry' WITH entry = entry -%]
[% END -%]
T

    entry => <<'T',
[% FOR child IN entry.next -%]
    - [% child.name %]
    [% INCLUDE 'entry' WITH entry = child ; -%]
[% END -%]
T
);

my @entries = (
 {
   name => 'hoge',
   next => [
     { name => 'fuga' },
     { name => 'foobar' }
   ]
 }
);

my $tx = Text::Xslate->new( syntax => 'TTerse', cache => 0, path => \%vpath );

ok $tx->render('entry', { entry => $entries[0] });

my $s = $tx->render('main', { entries => \@entries });
note $s;
ok $s;
like $s, qr/hoge/;
like $s, qr/fuga/;
like $s, qr/foobar/;

done_testing;

