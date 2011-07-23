#!perl
use strict;
use warnings;

use Amon2::Lite;

get '/' => sub {
    my ($c) = @_;
    $c->render('index.tt');
};
get '/hello' => sub {
    my ($c) = @_;
    $c->render('index.tt', { name => 'Amon2' });
};

sub res_404 {
    my($c) = @_;
    use Data::Dumper;
    die Dumper($c);
}

__PACKAGE__->to_app();

__DATA__

@@ index.tt
<!doctype html>
<html>
    <body><h1>Hello, [% name // 'Xslate' %] world!</body>
</html>
