#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Path;
use t::lib::Util;

rmtree(cache_dir);
END{ rmtree(cache_dir) }

is system($^X, (map { "-I$_" } @INC), "-we", <<'EOT', path, cache_dir), 0, 'compile' or die "failed to compile";
    #BEGIN{ ($ENV{XSLATE} ||= '') =~ s/dump//g; }
    use Text::Xslate;
    use t::lib::Util;
    my($path, $cache_dir) = @ARGV;
    my $tx = Text::Xslate->new(
        path      => [$path, { 'foo.tx' => 'Hello' } ],
        cache_dir => $cache_dir,
   );
   $tx->load_file('myapp/derived.tx');
   $tx->load_file('foo.tx');
EOT
ok -d cache_dir;

for my $cache(1 .. 2) {
    my $tx = Text::Xslate->new(
        path      => [path, { 'foo.tx' => 'Hello' } ],
        cache_dir => cache_dir,
        cache     => $cache,
    );

    for(1 .. 2) {
        like $tx->render('myapp/derived.tx', { lang => 'Xslate' }),
            qr/Hello, Xslate world!/, "cache => $cache";

        is $tx->render('foo.tx'), 'Hello';

        ok !exists $INC{'Text/Xslate/Compiler.pm'}, 'Text::Xslate::Compiler is not loaded';
    }
}

done_testing;
