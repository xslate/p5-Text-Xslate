#!perl -w
use strict;
use Test::More;

use Text::Xslate;

use FindBin qw($Bin);

sub mk_indent {
    my($prefix) = @_;

    return sub {
        my($str) = @_;
        $str =~ s/^/$prefix/xmsg;
        return $str;
    }
}

my $tx = Text::Xslate->new(
    function => {
        indent => \&mk_indent,
    },
);

my @set = (
    [ q{<: $value | indent("> ") :>}, { value => 'Xslate' }
        => '&gt; Xslate' ],

    [ q{<: $value | indent("> ") :>}, { value => "Xslate\nPerl\n" }
        => "&gt; Xslate\n&gt; Perl\n" ],

    [ q{: $value | indent("| ") }, { value => "Xslate\nPerl\n" }
        => "| Xslate\n| Perl\n" ],

    [ q{: indent("* ")($value) }, { value => "Xslate\nPerl\n" }
        => "* Xslate\n* Perl\n" ],
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;;
}

done_testing;
