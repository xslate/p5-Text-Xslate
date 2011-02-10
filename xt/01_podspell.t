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
EscapedString
sandboxing
APIs
runtime
autoboxing
backend
TT
adaptor
overridable
inline
Toolkit's
FillInForm
uri
CLI
PSGI
XSS
Mojo
SCALARs
namespace
CGI
xml
RT
XS
Exportable
Misc
callback
callbacks
RFC
colorize
Pre
IRC
irc
org

# personal name
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
typester
clouder
punytan
chiba
turugina
hirose
kane
taka

WAF
WAFs
JavaScript

