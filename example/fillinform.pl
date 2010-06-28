#!perl -w
use strict;

use Text::Xslate;

my $tx  = Text::Xslate->new(
    module => [qw(HTML::FillInForm::Lite) => [qw(fillinform)]],
);

print $tx->render_string(<<'T', { q => { foo => "<filled value>" } });
FillInForm
: block form | fillinform($q) | raw -> {
<form>
<input type="text" name="foo" />
</form>
: }
T
