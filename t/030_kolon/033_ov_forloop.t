#!perl -w
use strict;
use Test::More;

use Text::Xslate;

{
    package _defer;
    use overload '@{}' => sub { $_[0]->() };
}

sub defer(&) {
    my($coderef) = @_;
    return bless $coderef, '_defer';
}

my $tx = Text::Xslate->new();

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

done_testing;
