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
#Hello, [% lang %] world!
#T
#
#is $out, <<'X';
#header1
#header2
#Hello, Xslate world!
#footer1
#footer2
#X

#use Template;
#my $t = Template->new(
#    INCLUDE_PATH => [path],
#    ANYCASE      => 1,
#
#    WRAPPER      => ['wrapper1.tt', 'wrapper2.tt'],
#);
#
#my $out;
#$t->process(\<<'T', {lang => "Xslate"}, \$out) or die $t->error;
#Hello, [% lang %] world!
#T
#is $out, <<'X';
#<div class="wrapper1">
#<div class="wrapper2">
#Hello, Xslate world!
#</div>
#</div>
#X
my $t = Text::Xslate->new(
    syntax => 'TTerse',
    path   => path,
    cache  => 0,
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
    cache  => 0,
    header => ['config.tt', 'header1.tt'],
    footer => ['footer1.tt'],
);
$out = $t->render_string(<<'T');
Hello, [% lang %] world!
T

is $out, <<'X', 'header x 2 and footer x 2';
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

$out = $t->render_string(<<'T', { lang => 'Xslate' });
Hello, [% em(lang) %] world!
T

is $out, <<'X', 'call macros in header';
header1
Hello, <em>Xslate</em> world!
footer1
X

$t = Text::Xslate->new(
    syntax  => 'TTerse',
    path    => path,
    cache   => 0,
    wrapper => [qw(wrapper1.tt)],
);

$out = $t->render_string(<<'T', { lang => "Xslate" });
Hello, [% lang %] world!
T
is $out, <<'X', 'wrapper';
<div class="wrapper1">
Hello, Xslate world!
</div>
X

$t = Text::Xslate->new(
    syntax  => 'TTerse',
    path    => path,
    cache   => 0,
    wrapper => [qw(wrapper1.tt wrapper2.tt)],
);

$out = $t->render_string(<<'T', { lang => "TTerse" });
Hello, [% lang %] world!
T

is $out, <<'X', 'wrappers x 2';
<div class="wrapper1">
<div class="wrapper2">
Hello, TTerse world!
</div>
</div>
X

done_testing;
