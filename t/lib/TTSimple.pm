package TTSimple;

use strict;
use constant USE_TT => scalar(grep { $_ eq '--tt' } @ARGV) || $ENV{USE_TT};
use Carp;

use parent qw(Exporter);
our @EXPORT = qw(render_str render_file);

use lib "t/lib";
use Util;

my $tt;

if(USE_TT) {
    require Test::More;
    Test::More::note('use Template::Toolkit');

    require Template;
    $tt = Template->new(
        INCLUDE_PATH => path,
        ANYCASE      => 1,
    );
}
else {
    require Text::Xslate;
    require Text::Xslate::Syntax::TTerse;

    our %Func;
    $tt = Text::Xslate->new(
        path      => [path],
        cache_dir =>  path,
        cache     =>  0,
        syntax    => 'TTerse',
        warn_handler => \&Carp::confess,
        die_handler  => \&Carp::confess,

        function  => \%Func,
    );
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
        return $tt->render($in, $vars);
    }
}

sub render_str {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process(\$in, $vars, \$out) or croak $tt->error, "($in)";
        return $out;
    }
    else {
        return $tt->render_string($in, $vars);
    }
}

