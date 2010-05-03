#!perl -w

use strict;
use Test::More;

eval q{ use Test::Spelling && system("which", "spell") == 0 or die };

plan skip_all => q{Test::Spelling and spell(1) are not available.}
	if $@;

add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
Goro Fuji (gfx)
gfuji(at)cpan.org
Text::Xslate
xslate
todo
str
Opcode
gfx
cpan
render
Kolon
Metakolon
TTerse
syntaxes
