#!perl -w
use strict;

use Text::Xslate;
use HTML::Shakan;
use Plack::Request;

my $tx  = Text::Xslate->new();

sub app {
    my($env) = @_;
    my $req  = Plack::Request->new($env);

    my $form = HTML::Shakan->new(
        request => $req,
        fields  => [ TextField(name => 'name', label => 'Your name') ],
    );

    my $res = $req->new_response(200);

    $res->body( $tx->render_string(<<'T', { req => $req, form => $form }) );
<!doctype html>
<html>
<head><title>Building form</title></head>
<body>
<form>
<p>
Form:<br />
: $form.render() | raw
</p>
<p>
Source:<br />
<code>
: $form.render()
</code>
</p>
</body>
</html>
T
    return $res->finalize();

}

return \&app;
