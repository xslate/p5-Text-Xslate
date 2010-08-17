#!perl -w
use strict;
use Text::Xslate qw(html_builder);
use HTML::FillInForm::Lite 1.09;

sub fillinform {
    my($q) = @_;
    my $fif = HTML::FillInForm::Lite->new();
    return html_builder {
        my($html) = @_;
        return $fif->fill(\$html, $q);
    };
}

my $tx  = Text::Xslate->new(
    function => {
        fillinform => \&fillinform,
    },
    cache_dir => '.eg_cache',
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
