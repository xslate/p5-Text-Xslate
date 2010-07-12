#!perl -w
# test example/*.psgi

use strict;
use Test::Requires { 'Plack' => 0.99 };
use Test::More;

use HTTP::Request;
use Plack::Test;

unlink <example/*.txc>;

EXAMPLE: while(defined(my $example = <example/*.psgi>)) {
    note $example;

    my $expect = do {
        my $gold = $example;
        $gold =~ s/\.psgi$/.gold/;

        -e $gold or note("skip $example because it has no $gold"), next;

        open my $g, '<', $gold or die "Cannot open '$gold' for reading: $!";
        local $/;
        <$g>;
    };

    my $app = do $example;

    if($@) {
        if($@ =~ /Can't locate / # ' for poor editors
                or $@ =~ /version \S+ required--this is only version /) {
            note("skip $example because: $@");
        }
        else {
            fail "Error in $example: $@";
        }
        next EXAMPLE;
    }

    foreach(1 .. 2) {
        test_psgi
            app    => $app,
            client => sub {
                my $cb = shift;
                my $req = HTTP::Request->new(GET => "http://localhost/hello?name=foo&email=bar%40example.com");
                my $res = $cb->($req);
                is $res->content, $expect;
            },
        ;
    }
}

done_testing;
