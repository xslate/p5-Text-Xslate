package Text::Xslate::PP::Assembler;
use strict;
use Text::Xslate::PP::Const qw(:all);

my $state_class = 'Text::Xslate::PP::Opcode';

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub build {
    my ($class, $engine) = @_;
    $class->new(engine => $engine);
}

# >> copied and modified from Text::Xslate

sub assemble {
    my ( $self, $asm, $name, $fullpath, $cachepath, $mtime ) = @_;

    my $engine = $self->{engine};

    unless ( defined $name ) { # $name ... filename
        $name = '<string>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    my $st  = $state_class->new();

    $st->symbol({ %{$engine->{ function }} });

    my $tmpl = [];

    $engine->{ template }->{ $name } = $tmpl;
    $engine->{ tmpl_st }->{ $name }  = $st;

    $tmpl->[ Text::Xslate::PP::TXo_MTIME ]     = $mtime;
    $tmpl->[ Text::Xslate::PP::TXo_CACHEPATH ] = $cachepath;
    $tmpl->[ Text::Xslate::PP::TXo_FULLPATH ]  = $fullpath;

    $st->tmpl( $tmpl );
    $st->engine( $engine ); # weak_ref!

    $st->{sa}   = undef;
    $st->{sb}   = undef;

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $len = scalar( @$asm );

    $st->push_frame('main', $len);

    $st->code_len( $len );

    my $code = $st->code([]);
    my $macro;

    my $oi_line = -1;
    my $oi_file = $name;
    for ( my $i = 0; $i < $len; $i++ ) {
        my $c = $asm->[ $i ];

        if ( ref $c ne 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line, $file ) = @{$c};
        my $opnum = $Text::Xslate::PP::OPS{ $opname };

        unless ( defined $opnum ) {
            Carp::croak( sprintf( "Oops: Unknown opcode '%s' on [%d]", $opname, $i ) );
        }

        if(defined $line) {
            $oi_line = $line;
        }
        if(defined $file) {
            $oi_file = $file;
        }

        $code->[$i] = {
            # opcode
            opname => $opname,

            # opinfo
            line   => $oi_line,
            file   => $oi_file,
        };

        $code->[ $i ]->{ exec_code } = $Text::Xslate::PP::OPCODE[ $opnum ];

        my $oparg = $Text::Xslate::PP::OPARGS[ $opnum ];

        if ( $oparg & TXARGf_SV ) {

            # This line croak at 'concat'!
            # Carp::croak( sprintf( "Oops: Opcode %s must have an argument on [%d]", $opname, $i ) )
            #     unless ( defined $arg );

            if( $oparg & TXARGf_KEY ) {
                $code->[ $i ]->{ arg } = $arg;
            }
            elsif ( $oparg & TXARGf_INT ) {
                $code->[ $i ]->{ arg } = int($arg);

                if( $oparg & TXARGf_PC ) {
                    my $abs_addr = $i + $arg;

                    if( $abs_addr >= $len ) {
                        Carp::croak(
                            sprintf( "Oops: goto address %d is out of range (must be 0 <= addr <= %d)", $arg, $len )
                        );
                    }

                    $code->[ $i ]->{ arg } = $abs_addr;
                }

            }
            else {
                $code->[ $i ]->{ arg } = $arg;
            }

        }
        else {
            if( defined $arg ) {
                Carp::croak( sprintf( "Oops: Opcode %s has an extra argument on [%d]", $opname, $i ) );
            }
            $code->[ $i ]->{ arg } = undef;
        }

        # special cases
        if( $opnum == $Text::Xslate::PP::OPS{ macro_begin } ) {
            my $name = $code->[ $i ]->{ arg };
            if(!exists $st->symbol->{$name}) {
                require Text::Xslate::PP::Type::Macro;
                $macro = Text::Xslate::PP::Type::Macro->new(
                    name  => $name,
                    addr  => $i,
                    state => $st,
                );
                $st->symbol->{ $name } = $macro;
            }
            else {
                $macro = undef;
            }
        }
        elsif( $opnum == $Text::Xslate::PP::OPS{ macro_nargs } ) {
            if($macro) {
                $macro->nargs($code->[$i]->{arg});
            }
        }
        elsif( $opnum == $Text::Xslate::PP::OPS{ macro_outer } ) {
            if($macro) {
                $macro->outer($code->[$i]->{arg});
            }
        }
        elsif( $opnum == $Text::Xslate::PP::OPS{ depend } ) {
            push @{ $tmpl }, $code->[ $i ]->{ arg };
        }

    }

    push @{$code}, {
        exec_code => $Text::Xslate::PP::OPCODE[ $Text::Xslate::PP::OPS{end} ],
        file      => $oi_file,
        line      => $oi_line,
        opname    => 'end',
    }; # for threshold
    return;
}


