#!perl -w
use strict;
use Text::Xslate;
use HTML::FillInForm::Lite 1.09;

my $tx  = Text::Xslate->new(
    html_builder_module => [ 'HTML::FillInForm::Lite' => [qw(fillinform)] ],
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
