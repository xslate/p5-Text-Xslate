package Text::Xslate::Constants;
use strict;
use parent qw(Exporter);
use File::Spec;

our $DEBUG;
our @EXPORT_OK;

BEGIN {
    if (! defined($DEBUG)) {
        $DEBUG = $ENV{XSLATE} || '';
    }

    my $optimize = scalar(($DEBUG =~ /\b optimize=(\d+) \b/xms)[0]);
    if(not defined $optimize) {
        $optimize = 1; # enable optimization by default
    }
    my $default_display_width = 76;
    if($DEBUG =~ /display_width=(\d+)/) {
        $default_display_width = $1;
    }
    my %constants = (
        DEBUG => $DEBUG ? 1 : 0,

        DEFAULT_DISPLAY_WIDTH => $default_display_width,

        DUMP_ADDIX  => scalar($DEBUG =~ /\b ix \b/xms),
        DUMP_ASM    => scalar($DEBUG =~ /\b dump=asm \b/xms),
        DUMP_AST    => scalar($DEBUG =~ /\b dump=ast \b/xms),
        DUMP_CAS    => scalar($DEBUG =~ /\b dump=cascade \b/xms),
        DUMP_DENOTE => scalar($DEBUG =~ /\b dump=denote \b/xmsi),
        DUMP_GEN    => scalar($DEBUG =~ /\b dump=gen \b/xms),
        DUMP_LOAD   => scalar($DEBUG =~ /\b dump=load \b/xms),
        DUMP_PP     => scalar($DEBUG =~ /\b dump=pp \b/xms),
        DUMP_LOAD   => scalar($DEBUG =~ /\b dump=load \b/xms),

        PP_ERROR_VERBOSE => scalar($DEBUG =~ /\b pp=verbose \b/xms),

        DUMP_PROTO  => scalar($DEBUG =~ /\b dump=proto \b/xmsi),
        DUMP_TOKEN  => scalar($DEBUG =~ /\b dump=token \b/xmsi),
        OPTIMIZE    => $optimize,
        ST_MTIME => 9,

        DEFAULT_CACHE_DIR => File::Spec->catdir(
            $ENV{TEMPDIR} || File::Spec->tmpdir,
            'xslate_cache',
            $>
        ),

        OP_NAME    => 0,
        OP_ARG     => 1,
        OP_LINE    => 2,
        OP_FILE    => 3,
        OP_LABEL   => 4,
        OP_COMMENT => 5,

        FOR_LOOP   => 1,
        WHILE_LOOP => 2,
    );

    require constant;
    constant->import(\%constants);

    @EXPORT_OK = keys %constants;
}

1;