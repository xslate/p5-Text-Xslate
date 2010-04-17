#!perl -w

use strict;
use Test::Requires qw(Test::LeakTrace);
use Test::More;
use Text::Xslate;

no_leaks_ok {
    my $x = Text::Xslate->new(assembly => <<'TX_ASM', path => []);
        print_raw_s "Hello, "
        fetch       "my"
        fetch_field_s "lang"
        print
        print_raw_s " world!\n"
TX_ASM
} "new";

no_leaks_ok {
    my $x = Text::Xslate->new(assembly => <<'TX_ASM', path => []);
        print_raw_s "Hello, "
        fetch       "my"
        fetch_field_s "lang"
        print
        print_raw_s " world!\n"
TX_ASM

    my $text = $x->render({ my => { lang => 'Xslate' } });
    $text eq "Hello, Xslate world!\n" or die "render() failed: $text";
} "render (interpolate)";

no_leaks_ok {
    my $x = Text::Xslate->new(assembly => <<'TX_ASM', path => []);
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

    my $text = $x->render({ data => [ { title => 'foo' }, { title => 'bar' } ] });
    $text eq "* foo\n* bar\n" or die "render() failed: $text";
} "render (for)";


done_testing;
