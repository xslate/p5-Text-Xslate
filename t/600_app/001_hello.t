use strict;
use Test::More (tests => 4);
use File::Path ();

sub clean {
    File::Path::rmtree( "t/600_app/out" );
    File::Path::rmtree( ".cache" );
}

clean();
END{
    clean();
}

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    '--dest=t/600_app/out',
    '--cache_dir=.cache',
    '--verbose=1',
    '--escape=html',
    '--cache=0',
    't/600_app/simple/hello.tx'
;

is $?, 0, "command executed successfully";

ok -f 't/600_app/out/hello.txt', 'correct file generated';

my $fh;
ok open($fh, '<', 't/600_app/out/hello.txt'), 'file opened';

my $content = do { local $/; <$fh> };

like $content, qr/Hello, Perl world!/;
