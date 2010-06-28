use strict;
use Text::Xslate;
use Benchmark qw/ :all /;
use Path::Class qw/ file /;
END{ unlink "test.tx" }
file("test.tx")->openw->print(q{[% FOR i IN list %] [% i %] [% END %]});

my $tx = Text::Xslate->new( syntax => "TTerse" );
print $tx->VERSION, "\n";
timethese 0, {
    tx => sub {
        $tx->render("test.tx", { list => [ 1 .. 100 ] });
    },
};
