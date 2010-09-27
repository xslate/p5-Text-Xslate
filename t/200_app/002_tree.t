use strict;
use Test::More (tests => 8);
use File::Path ();
use FindBin qw($Bin);

sub clean {
    File::Path::rmtree( ".app_cache2" );
    File::Path::rmtree( ".tree_out" );
}

clean();
END{
    clean();
}

system $^X, (map { "-I$_" } @INC), "script/xslate",
    '--suffix', 'tx=txt',
    '--cache_dir=.xslate_cache/app2',
    '--dest=.tree_out',
    '--ignore=dont_touch',
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

    {
        ok  !-f '.tree_out/dont_touch.tx', '--ignore works';
    }
}


