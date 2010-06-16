#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Path;

rmtree('t/template/cache');
END{ rmtree('t/template/cache') }

system $^X, (map { "-I$_" } @INC), "-we", <<'EOT';
    use Text::Xslate;
    my $tx = Text::Xslate->new(
        cache_dir => 't/template/cache',
        path      => ['t/template'],
   );
   $tx->load_file('myapp/derived.tx');
EOT

ok -d 't/template/cache', '-d "t/template/cache"';

for(1 .. 2) {
    my $tx = Text::Xslate->new(
        path      => ['t/template'],
        cache_dir => 't/template/cache',
        cache     => 1,
    );

    like $tx->render('myapp/derived.tx', { lang => 'Xslate' }),
        qr/Hello, Xslate world!/, 'cache => 1';

    ok !exists $INC{'Text/Xslate/Compiler.pm'}, 'Text::Xslate::Compiler is not loaded';
}

for(1 .. 2) {
    my $tx = Text::Xslate->new(
        path      => ['t/template'],
        cache_dir => 't/template/cache',
        cache     => 2,
    );

    like $tx->render('myapp/derived.tx', { lang => 'Xslate' }),
        qr/Hello, Xslate world!/, 'cache => 2';

    ok !exists $INC{'Text/Xslate/Compiler.pm'}, 'Text::Xslate::Compiler is not loaded';
}

done_testing;
