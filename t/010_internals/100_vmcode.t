#!perl -w

use strict;
use Test::More;
use Text::Xslate;

use Carp ();

$SIG{__WARN__} = \&Carp::confess;

foreach my $i(0 .. 2) {
    my $x = Text::Xslate->new(assembly => <<'TX_ASM');
        print_raw_s   "Hello, "
        fetch         "my"
        fetch_field_s "lang"
        print
        print_raw_s   " world!\n"
TX_ASM


    for my $j(0 .. 2) {
        note "$i-$j";

        is $x->render({ my => { lang => 'Xslate' } }), "Hello, Xslate world!\n", 'interpolate';
        is $x->render({ my => { lang => 'Perl'   } }), "Hello, Perl world!\n",   'interpolate';

        my $out = $x->render({ my => { lang => 'Xslate' } });
        is $out, "Hello, Xslate world!\n", 'interpolate';

        eval {
            $x->render({});
        };
        like $@, qr/\b lang \b/xms, "correct error (interpolate)";
    }

    $x = Text::Xslate->new(assembly => <<'TX_ASM');
        fetch "data" # $data
        for_start 0  # $item
        print_raw_s "* "
        fetch_iter 0         # $item
        fetch_field_s "title"  # .title
        print
        print_raw_s "\n"
        literal 0 # $item
        for_next -6
TX_ASM

    is $x->render({ data => [ { title => "foo" }, { title => "bar" } ] }),
        "* foo\n* bar\n", 'for';

    is $x->render({ data => [ { title => "hoge" }, { title => "fuga" } ] }),
        "* hoge\n* fuga\n", 'for';

    eval {
        $x->render({ data => {} });
    };
    like $@, qr/must be an ARRAY reference/, "correct error (for)";

    eval {
        $x->render({ });
    };
    like $@, qr/must be an ARRAY reference/, "correct error (for)";
}


done_testing;
