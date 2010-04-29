#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Fatal qw(open);

use t::lib::Util;

my $tx = Text::Xslate->new(path => [path]);

eval {
    $tx->load_file("hello.tx");
};

is $@, '', "load_file -> success";

eval {
    $tx->load_file("no such file");
};

like $@, qr/^Xslate/, "load_file -> fail";
like $@, qr/LoadError/, "load_file -> fail";

open my($out), '>', path . "/hello.txc";
print $out "This is a broken txc file\n";
close $out;

eval {
    $tx->load_file("hello.tx");
};

is $@, '', 'XSLATE_MAGIC unmatched (-> auto reload)';

is $tx->render("hello.tx", { lang => 'Xslate'}), "Hello, Xslate world!\n";

unlink path . "/hello.txc";

done_testing;
