#!perl -w

use strict;
use Test::More;

eval q{ use Test::Spelling; system("which", "spell") == 0 or die };

plan skip_all => q{Test::Spelling and spell(1) are not available.}
	if $@;

add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
Text::Xslate
xslate
todo
str
Opcode
cpan
render
Kolon
Metakolon
TTerse
syntaxes
pre
namespaces
plugins
html
acknowledgement
iff
okey
EscapedString
sandboxing
APIs
runtime
autoboxing
backend

# name
lestrrat
tokuhirom
gardejo
jjn
Goro Fuji
gfx
Douglas Crockford
makamaka
Hannyaharamitu
Maki
Daisuke
