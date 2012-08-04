#!perl -w
use strict;
use Test::More;

use Text::Xslate;

{
    package _defer;
    use overload
        '@{}' => sub { $_[0]->() },
        '%{}' => sub { $_[0]->() },
        fallback => 1;

    package _str;
    use overload '""' => sub { 'foo' };
}

sub defer(&) {
    my($coderef) = @_;
    return bless $coderef, '_defer';
}

my $tx = Text::Xslate->new(verbose => 0);

my @data = (
    ['Hello,
: for $types -> ($type) {
[<:= $type :>]
: }
world!'
        => "Hello,\n[Str]\n[Int]\n[Object]\nworld!"],
);

my %vars = (
    types => defer { [qw(Str Int Object)] },
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    is $tx->render_string($in, \%vars), $out, $msg or do {
        diag($in);

        my $code = $tx->compile($in);
        diag("// assembly");
        diag($tx->_compiler->as_assembly($code));
    } for 1 .. 2;
}

ok ! eval {
    $tx->render_string(': for $foo -> $i { $i }',
        { foo => defer { 42 } }), '';
}, "broken overloading object";

is $tx->render_string(': for $foo -> $i { $i }',
    { foo => bless {}, '_str'}), '';

# is_array_ref() is_hash_ref() respect overloading
if(0) {
foreach my $x([], defer { [] }) {
    ok $tx->render_string(': is_array_ref($x)', { x => $x }),
        "is_array_ref($x)";
}

foreach my $x(0, {}, bless [], defer { "foo" }) {
    ok $tx->render_string(': !is_array_ref($x)', { x => $x }),
        "!is_array_ref($x)";
}

foreach my $x({}, defer { +{} }) {
    ok $tx->render_string(': is_hash_ref($x)', { x => $x }),
        "is_hash_ref($x)";
}

foreach my $x(0, [], bless {}, defer { "foo" }) {
    ok $tx->render_string(': !is_hash_ref($x)', { x => $x }),
        "!is_hash_ref($x)";
}
} # TODO: consider it later
done_testing;
