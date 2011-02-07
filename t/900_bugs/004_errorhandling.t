use strict;
use Text::Xslate;
use Test::More;

my $view = Text::Xslate->new(
    verbose  => 1,
    syntax   => 'TTerse',
    function => { f => sub { die } },
);

{

    package MyMap;

    sub wrapper {
        my ( $self, $res ) = @_;
        return $res;
    }

    sub call {
        my ( $self, $env ) = @_;

        my $app = sub {
            my $html = $view->render_string( <<'...' );
[% f() -%]
[% f() -%]
[% f() -%]
[% f() -%]
[% f() -%]
...

            return [ 200, [], [$html] ];
        };
        return $self->wrapper(
            $app->($env)
        );
    }
}

my $res = MyMap->call( {} );
is ref($res), 'ARRAY';

done_testing;

