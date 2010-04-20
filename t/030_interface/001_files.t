#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use FindBin qw($Bin);

my @caches = ("$Bin/../template/hello.txc", "$Bin/../template/for.txc");

ok !-e $_, "$_ does not exist" for @caches;

for(1 .. 10) {
    my $tx = Text::Xslate->new(
        file => 'hello.tx',

        auto_compile => 1,
    );


    is $tx->render({ lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

    $tx = Text::Xslate->new(
        file => 'for.tx',
        auto_compile => 1,
    );

    is $tx->render({ books => [ { title => "Foo" }, { title => "Bar" } ]}),
        "[Foo]\n[Bar]\n", "file";

    ok -e $_, "$_ exists" for @caches;

    if(($_ % 3) == 0) {
        my $t = time + $_;
        utime $t, $t, @caches;
    }
}

unlink @caches;

done_testing;
