#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Fatal qw(open);

use t::lib::Util;

my $tx = Text::Xslate->new(path => [path], cache_dir => '.');

unlink './hello.txc';
END{ unlink './hello.txc' }

eval {
    $tx->load_file("hello.tx");
};

is $@, '', "load_file -> success";

eval {
    $tx->load_file("no_such_file");
};

like $@, qr/LoadError/xms,          "load_file -> LoadError";
like $@, qr/\b no_such_file \b/xms, "include the filename";

open my($out), '>', "./hello.txc";
print $out "This is a broken txc file\n";
close $out;

eval {
    $tx->load_file("hello.tx");
};

is $@, '', 'XSLATE_MAGIC unmatched (-> auto reload)';

is $tx->render("hello.tx", { lang => 'Xslate'}), "Hello, Xslate world!\n";

done_testing;
