package t::lib::TTSimple;

use strict;
use constant USE_TT => $ENV{USE_TT};
use Carp;

use parent qw(Exporter);
our @EXPORT = qw(render_str render_file);

use t::lib::Util;

my $tt;

if(USE_TT) {
    require Template;
    $tt = Template->new(
        INCLUDE_PATH => path,
    );
}
else {
    require Text::Xslate;
    require Text::Xslate::Syntax::TTerse;
}

sub render_file {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process($in, $vars, \$out) or do {
            require Data::Dumper;
            croak Data::Dumper::Dumper($tt->error);
        };
        return $out;
    }
    else {
        $tt //= Text::Xslate->new(
            path      => [path],
            cache_dir =>  path,
            cache     =>  0,
            syntax    => 'TTerse',
        );
        return $tt->render($in, $vars);
    }
}

sub render_str {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process(\$in, $vars, \$out) or croak $tt->error;
        return $out;
    }
    else {
        my $tx = Text::Xslate->new(
            string    => $in,
            path      => [path],
            cache_dir =>  path,
            cache     =>  0,
            syntax    => 'TTerse',
        );
        return $tx->render($vars);
    }
}

