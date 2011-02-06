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
my $s  = $tx->render('main', { entries => \@entries });
like $s, qr/hoge/;
like $s, qr/fuga/;
like $s, qr/foobar/;
done_testing;

