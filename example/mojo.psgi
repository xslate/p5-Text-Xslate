#!perl
package HelloMojo;
use strict;
use warnings;
use Mojolicious 1.0;

use Mojolicious::Lite;
#use MojoX::Renderer::Xslate; # this is automatically loaded

plugin 'xslate_renderer';

get '/'      => 'index';
get '/:name' => 'index';

app->start;

__DATA__
@@ index.html.tx
<html>
<body>
Hello, <: $c.req.param('lang') // "Xslate" :> world!
</body>
</html>

