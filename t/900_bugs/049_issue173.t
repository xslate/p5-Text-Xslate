#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(syntax => 'Kolon');

my $tmpl;

$tmpl = <<'TX';
: macro br  { raw('<br>') }
: macro div { raw('<div>' ~ br()  ~ '</div>') }
: div()
TX

is $tx->render_string($tmpl), '<div><br></div>', 'macro concat';

$tmpl = <<'TX';
: macro br  { raw('<br>') }
: macro div { raw(['<div>', br(), '</div>'].join('')) }
: div()
TX

is $tx->render_string($tmpl), '<div><br></div>', 'macro join';

$tmpl = <<'TX';
: macro br        { raw('<br>') }
: macro div_open  { raw('<div>') }
: macro div_close { raw('</div>') }
: div_open() ~ br() ~ div_close()
TX

is $tx->render_string($tmpl), '<div><br></div>', 'template concat';

done_testing;
