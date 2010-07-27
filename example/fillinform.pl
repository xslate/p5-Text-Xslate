#!perl -w
use strict;
use Text::Xslate qw(mark_raw unmark_raw);
use HTML::FillInForm::Lite 1.09;

sub fillinform {
    my($q) = @_;

    return sub {
        my($html) = @_;
        return mark_raw(HTML::FillInForm::Lite->fill(\unmark_raw($html), $q));
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
