use strict;
use Test::More;

use Text::Xslate;

{
    package My::Text::Xslate::Provider::Hash;
    use strict;

    sub new {
        my $class = shift;
        bless {@_}, $class;
    }

    sub find_file {
        my ($self, $engine, $file) = @_;
        $self->{hash}->{$file};
    }

    sub load_file {
        my($self, $engine, $file, $mtime, $omit_augment) = @_;
        my $string = $self->find_file($engine, $file);
        my $asm = $engine->compile($string);
        $engine->_assemble($asm, $file, \$string, undef, undef);
        return $asm;
    }
};

my $provider = My::Text::Xslate::Provider::Hash->new(
    hash => {
      "hello.tx" => 'Hello, <: $name :>'
    }
);

my $tx = Text::Xslate->new(provider => $provider);
is $tx->render("hello.tx", {name => "Hash Hash"}), "Hello, Hash Hash";


done_testing;