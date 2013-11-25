package builder::MyBuilder;
use strict;
use warnings;
use utf8;
use parent qw(Module::Build::XSUtil);

sub new {
    my ( $self, %args ) = @_;
    $self->SUPER::new(
        %args,
        include_dirs => [qw(src/ .)],
        xs_files => {
            'src/Text-Xslate.xs' => 'lib/Text/Xslate.xs',
        },
        c_source => ['src'],
        generate_xshelper_h => 'xshelper.h',
        meta_merge     => {
            resources => {
                homepage    => 'http://xslate.org/',
                bugtracker  => 'https://github.com/xslate/p5-Text-Xslate/issues',
                repository  => 'https://github.com/xslate/p5-Text-Xslate',
                ProjectHome => 'https://github.com/xslate',
                MailingList => 'http://groups.google.com/group/xslate',
            }
        },
    );
}

sub ACTION_code {
    my $self = shift;

    system "$^X tool/opcode.PL        src/xslate_opcode.inc >xslate_ops.h";

    require ExtUtils::ParseXS;
    ExtUtils::ParseXS->new->process_file(
        filename => 'src/xslate_methods.xs',
        output => 'src/xslate_methods.c'
    );

    $self->SUPER::ACTION_code(@_);
}

1;
