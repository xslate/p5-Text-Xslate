use strict;
use Test::More (tests => 8);
use File::Path ();
use FindBin  qw($Bin);

sub clean {
    File::Path::rmtree( $Bin . "/out" );
    File::Path::rmtree( ".app_cache" );
}
clean();
END{
    clean();
}

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    sprintf('--dest=%s/out', $Bin),
    '--cache_dir=.app_cache',
    '--verbose=1',
    '--cache=2',
    sprintf('%s/simple/hello.tx', $Bin),
;

is $?, 0, "command executed successfully (1)";

ok -d '.app_cache', 'cache directry created';

ok -f sprintf('%s/out/hello.txt', $Bin), 'correct file generated';

my $fh;
ok open($fh, '<', sprintf('%s/out/hello.txt', $Bin)), 'file opened';

my $content = do { local $/; <$fh> };

like $content, qr/Hello, Perl world!/;

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    sprintf('--dest=%s/out', $Bin),
    '--cache_dir=.app_cache',
    '--define=lang=Xslate',
    '--cache=2',
    sprintf('%s/simple/hello.tx', $Bin),
;

is $?, 0, "command executed successfully (2)";

ok open($fh, '<', sprintf('%s/out/hello.txt', $Bin)), 'file opened';

$content = do { local $/; <$fh> };

like $content, qr/Hello, Xslate world!/;
