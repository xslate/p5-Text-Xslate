#!perl
# https://github.com/xslate/p5-Text-Xslate/issues/xx
use strict;
use warnings;
use Test::More;

use utf8;
use Text::Xslate 'mark_raw';
my $xslate = Text::Xslate->new();

# without the fix, these fail with 
# "Use of uninitialized value in subroutine entry"


my $t = sub {
    is $xslate->render_string('<: $s1 ~ $s2 :>', shift), shift;
};

$t->( {s1 => 'A',   s2 => 'B'   } => 'AB');
$t->( {s1 => 'A',   s2 => undef } => 'A');
$t->( {s1 => undef, s2 => 'B'   } => 'B');

$t->( {s1 => mark_raw('A'),   s2 => undef           } => 'A');
$t->( {s1 => undef,           s2 => mark_raw('B')   } => 'B');


# the automatic html-escaping that xslate does
$t->({s1 => 'A',             s2 => '<B>'           } => 'A&lt;B&gt;');
$t->({s1 => 'A',             s2 => mark_raw('<B>') } => 'A<B>'      );

$t->({s1 => '<A>',           s2 => 'B'             } => '&lt;A&gt;B');
$t->({s1 => mark_raw('<A>'), s2 => 'B'             } => '<A>B'      );

# those two again with undefs
$t->({s1 => '<A>',           s2 => undef           } => '&lt;A&gt;');
$t->({s1 => mark_raw('<A>'), s2 => undef           } => '<A>');

$t->({s1 => undef,           s2 => '<B>'           } => '&lt;B&gt;');
$t->({s1 => undef,           s2 => mark_raw('<B>') } => '<B>');

# undef on both sides
$t->({s1 => undef,           s2 => undef           } => '');

done_testing();
