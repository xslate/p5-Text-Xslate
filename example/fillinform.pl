#!perl -w
use strict;
use Text::Xslate qw(mark_raw);
BEGIN { eval { require HTML::FillInForm::Lite::Compat } }
use HTML::FillInForm;

sub fillinform {
    my($q) = @_;

    return sub {
        my($html) = @_;
        return mark_raw(HTML::FillInForm->fill(\$html, $q));
    };
}

my $tx  = Text::Xslate->new(
    function => {
        fillinform => \&fillinform,
    },
);

my %vars = (
    q => { foo => "<filled value>" },
);
print $tx->render_string(<<'T', \%vars);
FillInForm:
: block form | fillinform($q) -> {
<form>
<input type="text" name="foo" />
</form>
: }
T
