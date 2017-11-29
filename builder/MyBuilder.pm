package builder::MyBuilder;
use strict;
use warnings;
use base 'Module::Build::XSUtil';

sub new {
    my ($class, %args) = @_;

    $class->SUPER::new(
        %args,
        c_source => ['src'],
        cc_warnings => 1,
        generate_ppport_h => 'src/ppport.h',
        generate_xshelper_h => 'src/xshelper.h',
        xs_files => { 'src/Text-Xslate.xs' => 'lib/Text/Xslate.xs' },
    );
}

sub _derive_opcode {
    my ($self, $script, $source, $derived) = @_;
    my @cmd = ($self->{properties}{perl}, $script, $source);
    $self->log_info("@cmd > $derived\n");
    open my $fh, ">", $derived or die "$derived: $!";
    print {$fh} $self->_backticks(@cmd);
}

sub ACTION_code {
    my ($self, @args) = @_;

    my @derive = (
        {
            xs => 0,
            source => "src/xslate_opcode.inc",
            derived => "lib/Text/Xslate/PP/Const.pm",
            code => sub {
                my ($self, $source, $derived) = @_;
                $self->_derive_opcode("tool/opcode_for_pp.PL", $source, $derived);
            },
        },
        {
            xs => 1,
            source => "src/xslate_opcode.inc",
            derived => "src/xslate_ops.h",
            code => sub {
                my ($self, $source, $derived) = @_;
                $self->_derive_opcode("tool/opcode.PL", $source, $derived);
            },
        },
        {
            xs => 1,
            source => "src/xslate_methods.xs",
            derived => "src/xslate_methods.c",
            code => sub {
                my ($self, $source, $derived) = @_;
                $self->compile_xs($source, outfile => $derived);
            },
        }

    );
    for my $derive (@derive) {
        next if $self->pureperl_only and $derive->{xs};
        next if $self->up_to_date($derive->{source}, $derive->{derived});
        $derive->{code}->($self, $derive->{source}, $derive->{derived});
    }

    $self->SUPER::ACTION_code(@args);
}

sub ACTION_test {
    my ($self, @args) = @_;
    local $ENV{PERL_ONLY} = 1 if $self->pureperl_only;
    $self->SUPER::ACTION_test(@args);
}

1;