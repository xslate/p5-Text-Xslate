use strict;
use Text::Xslate;
use Test::More;

my $view = Text::Xslate->new(
    verbose  => 1,
    'syntax' => 'TTerse',
);

{

    package MyMap;

    sub new {
        my $proto = shift;
        return bless {@_}, $proto;
    }

    sub wrapper {
        my ( $self, $res ) = @_;
        return $res;
    }

    sub call {
        my ( $self, $env ) = @_;

        my $app = sub {
            my $args =
              { p => +{ cs => [ map { bless {}, __PACKAGE__ } 1 .. 3 ] } };

            my $html = $view->render_string( <<'...', $args );
[% FOR c IN p.cs %]
v1
[% c.x %]
[% c.y %]
[% END %]
...

            return [ 200, [], [$html] ];
        };
        return $self->wrapper(
            $app->($env)
        );
    }
}

my $map = MyMap->new();
my $res = $map->call( {} );
is ref($res), 'ARRAY';

done_testing;

