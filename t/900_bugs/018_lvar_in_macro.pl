# This code caused SEGV in Perl 5.12 by Xslate 1.5
use strict;
use warnings;
use Test::More;
use Text::Xslate;

my $engine = Text::Xslate->new(
 'syntax' => 'TTerse',
);

$engine->render_string( <<'...') ;
[% kogaidan = kogaidan -%]
[% tomyhero = dankogai %]

[% MACRO satoshi BLOCK %]
[% tomyhero # caused SEGV %]
[% END %]

[% satoshi() %]
...

pass;
done_testing;

