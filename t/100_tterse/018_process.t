#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;
use t::lib::Util;
use Text::Xslate::Util qw(p);
#use Template;
#my $t = Template->new(
#    INCLUDE_PATH => [path],
#    ANYCASE      => 1,
#
#    PRE_PROCESS  => ['header1.tt', 'header2.tt'],
#    POST_PROCESS => ['footer1.tt', 'footer2.tt'],
#);
#
#my $out;
#$t->process(\<<'T', {lang => "Xslate"}, \$out) or die $t->error;
my $t = Text::Xslate->new(
    syntax => 'TTerse',
    path   => path,
    header => ['header1.tt', 'header2.tt'],
    footer => ['footer1.tt', 'footer2.tt'],
);
my $out = $t->render_string(<<'T', { lang => "Xslate" });
Hello, [% lang %] world!
T

is $out, <<'X';
header1
header2
Hello, Xslate world!
footer1
footer2
X

$t = Text::Xslate->new(
    syntax => 'TTerse',
    path   => path,
    header => ['config.tt', 'header1.tt'],
    footer => ['footer1.tt'],
);
$out = $t->render_string(<<'T');
Hello, [% lang %] world!
T

is $out, <<'X';
header1
Hello, TTerse world!
footer1
X

$out = $t->render_string(<<'T', { lang => 'Xslate' });
Hello, [% lang %] world!
T

is $out, <<'X';
header1
Hello, Xslate world!
footer1
X

done_testing;
