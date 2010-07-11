#!perl -w
BEGIN{ $ENV{XSLATE} ||= 'pp=booster;dump=pp;' }

use strict;
use Text::Xslate;

my $tx = Text::Xslate->new();

$tx->render_string( <<'CODE', {} );
: macro foo -> $arg {
    Hello <:= $arg :>!
: }
: foo($value)
CODE
