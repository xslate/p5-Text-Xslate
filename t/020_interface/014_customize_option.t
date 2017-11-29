#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Parser;

use Fatal qw(open);
use File::Path qw(rmtree);

use lib "t/lib";
use Util;

package MyXslate;
{
    use Mouse;

    extends qw(Text::Xslate);

    sub compiler_option {
        my $self = shift;
        +{
            %{ $self->SUPER::compiler_option },
            my_compiler_option => undef,
        };
    }

    sub parser_option {
        my $self = shift;
        +{
            %{ $self->SUPER::parser_option },
            my_parser_option => undef,
        };
    }

    sub replace_option_value_for_magic_token {
        my($self, $name, $value) = @_;

        return $name if $name eq 'my_compiler_option';
        return $name if $name eq 'my_parser_option';
        return $value;
    }

    no Mouse;

    package MyCompiler;

    use Mouse;

    extends qw(Text::Xslate::Compiler);

    has my_compiler_option => (
        is       => 'rw',
    );

    no Mouse;
    __PACKAGE__->meta->make_immutable();
}
package MySyntax;
{
    use Mouse;

    extends qw(Text::Xslate::Parser);

    has my_parser_option => (
        is       => 'rw',
    );

    no Mouse;
    __PACKAGE__->meta->make_immutable();
}
package main;

my $stderr;
my $tx;
{
    local *STDERR;
    open STDERR, '>:scalar', \$stderr;

    $stderr = '';
    $tx = Text::Xslate->new(
        my_compiler_option => 'foo',
        my_parser_option => 'bar',
    );
    like($stderr, qr/Unknown option\(s\): my_compiler_option my_parser_option/, 'detect unknown option');

    $stderr = '';
    $tx = MyXslate->new(
        compiler => 'MyCompiler',
        syntax => 'MySyntax',
        my_compiler_option => 'foo',
        my_parser_option => 'bar',
    );
    unlike($stderr, qr/Unknown option/, 'no unknown option error');
}

$tx->render_string('');
is($tx->{compiler}{my_compiler_option}, 'foo', 'my_compiler_option');
is($tx->{compiler}{parser}{my_parser_option}, 'bar', 'my_parser_option');

#
$tx = MyXslate->new(path => [path], cache_dir => cache_dir,
                    compiler => 'MyCompiler',
                    syntax => 'MySyntax',
                    my_compiler_option => sub {},
                    my_parser_option => sub {},
                );
rmtree cache_dir;
END{ rmtree cache_dir }

eval {
    $tx->load_file("hello.tx");
};
is $@, '', "load_file -> success";

done_testing;
