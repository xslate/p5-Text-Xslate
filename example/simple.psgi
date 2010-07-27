#!psgi -w
use strict;
use Text::Xslate;
use Plack::Request;

my %vpath = (
    'hello.tx' => <<'TX',
<!doctype html>
<html>
<head>
<title>hello</title>
</head>
<body>
<form><p>
<input type="text" name="lang" />
<input type="submit" />
</p></form>
<p>Hello, <: $lang :> world!</p>
</body>
</html>
TX
);

my $tx = Text::Xslate->new(
    path      => \%vpath,
    cache_dir => '.eg_cache',
);

sub app {
    my($env) = @_;
    my $req  = Plack::Request->new($env);
    my $res  = $req->new_response(
        200,
        [content_type => 'text/html; charset=utf-8'],
    );
    my %vars = (
        lang => $req->param('lang') || '<Xslate>',
    );
    my $body = $tx->render('hello.tx', \%vars);
    utf8::encode($body);
    $res->body($body);
    return $res->finalize();
}

return \&app;
