#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Path;
use Config;

use t::lib::Util ();

my $path = t::lib::Util::path();
my $cache_dir = t::lib::Util::cache_dir;
rmtree($cache_dir);
END{ rmtree($cache_dir) }
# XXX: @INC is too long to pass a command, so we need to give it via %ENV
$ENV{PERL5LIB} = join $Config{path_sep}, @INC;
is system($^X, "-we", <<'EOT', $path, $cache_dir), 0, 'compile' or die "failed to compile";
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
ok -d $cache_dir;

for my $cache(1 .. 2) {
    my $tx = Text::Xslate->new(
        path      => [$path, { 'foo.tx' => 'Hello' } ],
        cache_dir => $cache_dir,
        cache     => $cache,
    );

    for(1 .. 2) {
        like $tx->render('myapp/derived.tx', { lang => 'Xslate' }),
            qr/Hello, Xslate world!/, "cache => $cache (render/path)";

        is $tx->render('foo.tx'), 'Hello', 'render/vpath';

        ok !exists $INC{'Text/Xslate/Compiler.pm'}, 'Text::Xslate::Compiler is not loaded';
    }
    #note(explain($tx->{_cache_path}));
}

done_testing;
