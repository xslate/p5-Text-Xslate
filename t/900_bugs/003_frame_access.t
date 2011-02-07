#!perl -w
use strict;
use warnings;

use Test::More;

use Text::Xslate;

my %vpath = (
    main => <<'T',
[% FOR entry IN entries -%]
    [% INCLUDE 'entry' WITH entry = entry %]
[% END -%]
T

    entry => <<'T',
[% FOR child IN entry.next %]
    [% INCLUDE 'entry' WITH entry = child ; # SEGV HERE %]
[% END %]
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
ok $s;
done_testing;

