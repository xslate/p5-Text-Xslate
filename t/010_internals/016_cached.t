#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Path;
use File::Temp 'tempfile';
use Config;

use lib "t/lib";
use Util ();

my $path = Util::path();
my $cache_dir = Util::cache_dir;
rmtree($cache_dir);
END{ rmtree($cache_dir) }

my ($tempfh, $tempname) = tempfile(UNLINK => 1);
print {$tempfh} <<'EOT';
use strict;
use warnings;
use Text::Xslate;
use lib "t/lib";
use Util;
my($path, $cache_dir) = @ARGV;
my $tx = Text::Xslate->new(
    path      => [$path, { 'foo.tx' => 'Hello' } ],
    cache_dir => $cache_dir,
);
$tx->load_file('myapp/derived.tx');
$tx->load_file('foo.tx');
EOT
close $tempfh;

# XXX: @INC is too long to pass a command, so we need to give it via %ENV
$ENV{PERL5LIB} = join $Config{path_sep}, @INC;
is system($^X, $tempname, $path, $cache_dir), 0, 'compile' or die "failed to compile";

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
