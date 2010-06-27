#!perl -w
use strict;

use Text::Xslate;
use Text::Xslate::Util qw(p mark_raw);
use HTML::FillInForm::Lite;

sub fillinform {
    my($q) = @_;

    return sub {
        my($html) = @_;
        return HTML::FillInForm::Lite->fill(\$html, $q);
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
