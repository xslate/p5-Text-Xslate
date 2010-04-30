package t::lib::TTSimple;

use strict;
use constant USE_TT => $ENV{USE_TT};
use Carp;

use parent qw(Exporter);
our @EXPORT = qw(render_str);

my $tt;

if(USE_TT) {
    require Template;
    $tt = Template->new();
}
else {
    require Text::Xslate::Compiler;
    require Text::Xslate::Parser::TTerse;

    $tt = Text::Xslate::Compiler->new(
        parser => Text::Xslate::Parser::TTerse->new(),
    );
}

sub render_str {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process(\$in, $vars, \$out) or croak $tt->error;
        return $out;
    }
    else {
        my $x = $tt->compile_str($in);
        return $x->render($vars);
    }
}

