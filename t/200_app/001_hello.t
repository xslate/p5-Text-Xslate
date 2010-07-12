use strict;
use Test::More (tests => 4);
use File::Path ();
use FindBin  qw($Bin);

sub clean {
    File::Path::rmtree( $Bin . "/out" );
    File::Path::rmtree( ".cache" );
}
clean();
END{
    clean();
}

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    sprintf('--dest=%s/out', $Bin),
    '--cache_dir=.cache',
    '--verbose=1',
    '--escape=html',
    '--cache=2',
    sprintf('%s/simple/hello.tx', $Bin),
;

is $?, 0, "command executed successfully";

ok -f sprintf('%s/out/hello.txt', $Bin), 'correct file generated';

my $fh;
ok open($fh, '<', sprintf('%s/out/hello.txt', $Bin)), 'file opened';

my $content = do { local $/; <$fh> };

like $content, qr/Hello, Perl world!/;
