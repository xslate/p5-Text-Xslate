#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Fatal qw(open);
use File::Path qw(rmtree);

use t::lib::Util;

my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

rmtree cache_dir;
END{ rmtree cache_dir }

eval {
    $tx->load_file("hello.tx");
};

is $@, '', "load_file -> success";

eval {
    $tx->load_file("no_such_file");
};

like $@, qr/LoadError/xms,          "load_file -> LoadError";
like $@, qr/\b no_such_file \b/xms, "include the filename";

my $cache = $tx->find_file('hello.tx')->{cachepath};
ok -e $cache, "$cache exists";
open my($out), '>', $cache;
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
    cache_dir => cache_dir,
    cache     => 1,
);

my $fi = $tx->find_file('foo.tx');
ok !defined($fi->{cache_mtime})
    or diag explain($fi);

$tx->load_file('foo.tx');

$fi = $tx->find_file('foo.tx');
ok defined($fi->{cache_mtime})
    or diag explain($fi);

eval {
    $tx->find_file(File::Spec->catfile(File::Spec->updir, 'foo.tx'));
};
like $@, qr/Forbidden/, "updir ('..') is forbidden";
like $@, qr/updir/;
like $@, qr/foo\.tx/;

eval {
    $tx->find_file(('/..' x 10) . '/etc/passwd');
};
like $@, qr/Forbidden/;
like $@, qr/updir/;
like $@, qr{/etc/passwd};
done_testing;
