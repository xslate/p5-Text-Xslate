use Plack::Builder;
use Text::Xslate;
use Plack::Response;
use Plack;
use Plack::Loader;
use Plack::Test;

warn "START\n";
warn "Plack: $Plack::VERSION\n";
warn "Text::Xslate: $Text::Xslate::VERSION\n";

# my env:
# Plack: 0.9967
# Text::Xslate: 1.0003

my $view = Text::Xslate->new(
    verbose => 1,
    'syntax' => 'TTerse',
);

my $app = builder {
    enable 'StackTrace';

    mount '/' => sub {
        my $args = {
            p => +{ cs => [ map { bless {}, __PACKAGE__ } 1..3 ] }
        };

        my $html = $view->render_string(<<'...', $args );
[% FOR c IN p.cs %]
foobar
[% c.x %]
[% c.y %]
[% END %]
...

        return [ 200, [], [$html] ];
    };
};

test_psgi app => $app,
    client => sub {
        my($cb) = @_;
        my $res = $cb->( HTTP::Request->new(GET => 'http://localhost/') );

        ok $res->is_success, $res->status_line;
        like $res->content, qr/foobar/;
    };
