#!perl
# contributed by Yappo https://gist.github.com/4336310
use strict;
use warnings;
use Test::More;

use Text::Xslate;

{
    my $tx = Text::Xslate->new({
        syntax => 'TTerse'
    });
    is eval {
        $tx->render_string(<<'TMPL', { yappo => 'hoge' });
[% SET yappo = "" -%]
[% IF true -%]
[%   yappo = 'osawa' -%]
[%   yappo -%]
[% ELSIF 0 -%]
[% END -%]
TMPL
    }, "osawa";
    is $@, '';
}

{
    my $tx = Text::Xslate->new({
        syntax => 'TTerse'
    });
    is eval {
        $tx->render_string(<<'TMPL', { yappo => 'hoge' });
[% SET yappo = 'fuga' -%]
[% IF true -%]
[%   yappo = 'seiidaishogun' -%]
[% ELSIF false -%]
[%   yappo = 'osawa' -%]
[% END -%]
[% yappo -%]
TMPL
    }, "seiidaishogun";
    is $@, '';
}

{
    my $tx = Text::Xslate->new({
        syntax => 'TTerse'
    });
    is eval {
        $tx->render_string(<<'TMPL', { yappo => 'hoge' });
[% IF true -%]
[%   yappo = 'seiidaishogun' -%]
[% ELSIF false -%]
[%   yappo = 'osawa' -%]
[% END -%]
[% yappo -%]
TMPL
    }, "hoge";
    is $@, '';
}

done_testing;
