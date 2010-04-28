#!perl -w

use strict;
use if $] == 5.010_000, 'Test::More', 'skip_all' => '5.10.0 has a bug about weak refs';
use Test::Requires qw(Test::LeakTrace);
use Test::More;
use Text::Xslate;
use Text::Xslate::Compiler;

my $txc = Text::Xslate::Compiler->new();

$txc->define_constant(uc => sub{ uc $_[0] });

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        Hello, <:= $my.lang :> world!
TX
} "new";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        Hello, <:= $my.lang :> world!
TX

    my $text = $x->render({ my => { lang => 'Xslate' } });
    $text eq <<'TEXT' or die "render() failed: $text";
        Hello, Xslate world!
TEXT
} "render (interpolate)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        : for $data -> ($item) {
            [<:= $item.title :>]
        : }
TX

    my $text = $x->render({ data => [ { title => 'foo' }, { title => 'bar' } ] });
    $text eq <<'TEXT' or die "render() failed: $text";
            [foo]
            [bar]
TEXT
} "render (for)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        <:= ($value + 10) * 2 :>
TX
    my $text = $x->render({ value => 11 });
    $text eq <<'TEXT' or die "render() failed: $text";
        42
TEXT

    $x = $txc->compile_str(<<'TX');
        <:= ($value - 10) / 2 :>
TX
    $text = $x->render({ value => 32 });
    $text eq <<'TEXT' or die "render() failed: $text";
        11
TEXT

    $x = $txc->compile_str(<<'TX');
        <:= $value % 2 :>
TX
    $text = $x->render({ value => 32 });
    $text eq <<'TEXT' or die "render() failed: $text";
        0
TEXT

} "render (expr)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        <:= "|" ~ $value ~ "|" :>
TX

    my $text = $x->render({ value => 'Xslate' });
    $text eq <<'TEXT' or die "render() failed: $text";
        |Xslate|
TEXT
} "render (concat)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        <:= $value > 10 ? "> 10" : "<= 10" :>
TX

    my $text = $x->render({ value => 10 });
    $text eq <<'TEXT' or die "render() failed: $text";
        &lt;= 10
TEXT

    $text = $x->render({ value => 11 });
    $text eq <<'TEXT' or die "render() failed: $text";
        &gt; 10
TEXT
} "render (ternary)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        <:= $value | uc :>
TX

    my $text = $x->render({ value => 'Xslate' });
    $text eq <<'TEXT' or die "render() failed: $text";
        XSLATE
TEXT
} "render (filter)";

no_leaks_ok {
    my $x = $txc->compile_str(<<'TX');
        <:= uc($value) :>
TX

    my $text = $x->render({ value => 'Xslate' });
    $text eq <<'TEXT' or die "render() failed: $text";
        XSLATE
TEXT
} "render (call)";

done_testing;
