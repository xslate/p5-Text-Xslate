#!perl -w
use strict;

use Text::Xslate;
use Data::Section::Simple;

my $tx = Text::Xslate->new(
    path      => [ Data::Section::Simple->new()->get_data_section() ],
    cache_dir => '.eg_cache',
);

print $tx->render('child.tx');

__DATA__

@@ base.tx
<html>
<body>
<: block body -> { :>default body<: } :>
</body>
</html>
@@ child.tx
: cascade base;
: override body -> {
child body
: } # endblock body
