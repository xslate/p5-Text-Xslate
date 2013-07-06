#!perl -w

use strict;
use Test::More;

eval q{ use Test::Spellunker };

plan skip_all => q{Test::Spellunker are not available.}
	if $@;

add_stopwords(map { split /[\s\:\-]/ } <DATA>);
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
WAF
WAFs
JavaScript
fallbacks
UTF
preforking
github
Mojolicious
HTMLTemplate
blog

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
cho
shmorimo
ueda
parens
opcodes
ing
vs
metacharacters
metacharacters
expressionsi
name-coderef
cb
cb
render
render_string
tx
newlines
