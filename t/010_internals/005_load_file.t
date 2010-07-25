#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Fatal qw(open);
use File::Path qw(rmtree);

use t::lib::Util;

my $tx = Text::Xslate->new(path => [path], cache_dir => '.cache');

rmtree '.cache';
END{ rmtree '.cache' }

eval {
    $tx->load_file("hello.tx");
};

is $@, '', "load_file -> success";

eval {
    $tx->load_file("no_such_file");
};

like $@, qr/LoadError/xms,          "load_file -> LoadError";
like $@, qr/\b no_such_file \b/xms, "include the filename";

open my($out), '>', ".cache/hello.txc";
print $out "This is a broken txc file\n";
close $out;

eval {
    $tx->load_file("hello.tx");
};

is $@, '', 'XSLATE_MAGIC unmatched (-> auto reload)';

is $tx->render("hello.tx", { lang => 'Xslate'}), "Hello, Xslate world!\n";

# virtual paths

my %vpath = (
    'foo.tx' => 'Hello, world!',
);
$tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.cache',
    cache     => 1,
);

my $fi = $tx->find_file('foo.tx');
ok !defined($fi->{cache_mtime})
    or diag explain($fi);

$tx->load_file('foo.tx');

$fi = $tx->find_file('foo.tx');
ok defined($fi->{cache_mtime})
    or diag explain($fi);

done_testing;
