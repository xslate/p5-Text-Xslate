#!perl
package HelloMojo;
use strict;
use warnings;
use Mojolicious 0.999934;

use Mojolicious::Lite;
use MojoX::Renderer::Xslate; # this should be automatically loaded

local @ARGV = qw(PSGI) unless @ARGV;

plugin 'xslate_renderer';

get '/:name' => 'index';

app->start;

__DATA__
@@ index.html.tx
<html>
<body>
Hello, <: $c.req.param('lang') // "Xslate" :> world!
</body>
</html>

