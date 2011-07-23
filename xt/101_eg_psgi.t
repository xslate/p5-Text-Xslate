#!perl -w
# test example/*.psgi

use strict;
use Test::More;

use HTTP::Request::Common;
use Plack::Test;

use File::Path qw(rmtree);

rmtree '.eg_cache';
END{ rmtree '.eg_cache' }

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
        fail "Error on loading $example: $@";
        next EXAMPLE;
    }

    foreach(1 .. 2) {
        test_psgi
            app    => $app,
            client => sub {
                my $cb = shift;
                my $req = GET "http://localhost/hello"
                             ."?name=foo&email=bar%40example.com";
                my $res = $cb->($req);
                is $res->content, $expect;
            },
        ;
    }
}

done_testing;
