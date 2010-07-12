use strict;
use Test::More (tests => 7);
use File::Path ();
use FindBin qw($Bin);

sub clean {
    File::Path::rmtree( ".cache" );
    File::Path::rmtree( ".tree_out" );
}

clean();
END{
    clean();
}

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    '--cache_dir=.cache',
    '--dest=.tree_out',
    "$Bin/simple",
;

if (is $?, 0, "command executed successfully") {
    {
        ok -f '.tree_out/hello.txt', 'correct file generated';
        my $fh;
        ok open($fh, '<', '.tree_out/hello.txt'), 'file opened';

        my $content = do { local $/; <$fh> };
        like $content, qr/Hello, Perl world!/;
    }

    {
        ok -f '.tree_out/goodbye.txt', 'correct file generated';
        my $fh;
        ok open($fh, '<', '.tree_out/goodbye.txt'), 'file opened';

        my $content = do { local $/; <$fh> };
        like $content, qr/Goodbye, Cruel world!/;
    }
}


