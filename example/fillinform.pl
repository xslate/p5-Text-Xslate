#!perl -w
use strict;

use Text::Xslate;
BEGIN {
    eval{ require HTML::FillInForm::Lite::Compat };
}
use HTML::FillInForm;

sub fillinform {
    my($q) = @_;

    return sub {
        my($html) = @_;
        return HTML::FillInForm->fill(\$html, $q);
    };
}

my $tx  = Text::Xslate->new(
    cache => 0,
    function => {
        fillinform => \&fillinform,
    },
);

print $tx->render_string(<<'T', { q => { foo => "<filled value>" } });
FillInForm
: block form | fillinform($q) | raw -> {
<form>
<input type="text" name="foo" />
</form>
: }
T
