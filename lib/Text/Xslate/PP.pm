package Text::Xslate::PP;

use 5.008; # finally even other modules will run in Perl 5.008?
use strict;

use parent qw(Exporter);
our @EXPORT_OK;
our @EXPORT;

use Carp ();
use Data::Dumper;

use Text::Xslate::PP::Const;
use Text::Xslate::PP::State;

my $TX_OPS = \%Text::Xslate::OPS;

my $Depth = 0;

our $VERSION = '0.0001';

our $XS_COMAPT_VERSION = '0.1011';

my $loaded;

unless ( $loaded++ ) {
    my $called_by = caller;

    if ( $called_by->isa('Text::Xslate') ) {
        @EXPORT = qw( _initialize render _reset_depth ); # for Text::Xslate
        *Text::Xslate::escaped_string = *Text::Xslate::PP::escaped_string;
    }
    else { # directly PP called
        @EXPORT_OK = qw( escaped_string html_escape );
        require Text::Xslate::PP::Methods; # install Text::Xslate methods
    }

    unless ( exists &Text::Xslate::EscapedString::new ) {
        _make_xslate_escapedstring_class();
    }

}


#
# real PP code
#

sub render {
    my ( $self, $name, $vars ) = @_;

    Carp::croak("Usage: Text::Xslate::render(self, name, vars)") if ( @_ != 3 );

    if ( !defined $name ) {
        $name = '<input>';
    }

    unless ( $vars and ref $vars eq 'HASH' ) {
        Carp::croak( sprintf("Xslate: Template variables must be a HASH reference, not %s", $vars ) );
    }

    my $st = tx_load_template( $self, $name );

    tx_execute( $st, undef, $vars );

    $st->{ output };
}


sub _initialize {
    my ( $self, $proto, $name, $fullpath, $cachepath, $mtime ) = @_;
    my $len = scalar( @$proto );
    my $st  = Text::Xslate::PP::State->new;

    # この処理全体的に別のところに移動させたい

    #unless ( $self->{ template } ) {
    #}

    unless ( defined $name ) { # $name ... filename
        $name = '<input>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    if ( $self->{ function } ) {
        $st->function( $self->{ function } );
    }

    my $tmpl = [];

    $self->{ template }->{ $name } = $tmpl;
    $self->{ tmpl_st }->{ $name }  = $st;

    $tmpl->[ Text::Xslate::PP::Opcode::TXo_NAME ]      = $name;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_MTIME ]     = $mtime;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_CACHEPATH ] = $cachepath;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_FULLPATH ]  = $fullpath;

    if ( $self->{ error_handler } ) {
        $tmpl->[ Text::Xslate::PP::Opcode::TXo_ERROR_HANDLER ] = $self->{ error_handler };
    }
    else { # シグナルハンドラは使わない方向で
        $tmpl->[ Text::Xslate::PP::Opcode::TXo_ERROR_HANDLER ] = sub {
            my ( $str ) = @_;
            my $st = $Text::Xslate::PP::Opcode::current_st;

            Carp::croak( $str ) unless $st;

            my $cframe = $st->frame->[ $st->current_frame ];
            my $name   = $cframe->[ Text::Xslate::PP::Opcode::TXframe_NAME ];

            $st->self->_reset_depth;

            #    /* unroll the stack frame */
            #    /* to fix TXframe_OUTPUT */

            local $Carp::CarpLevel = 2;
            local $Carp::Internal{ 'Text::Xslate::PP::Opcode' } = 1;
            local $Carp::Internal{ 'Text::Xslate::PP' } = 1;

            my $file = $st->tmpl->[ Text::Xslate::PP::Opcode::TXo_NAME ];
            my $line = $st->lines->[ $st->{ pc } ];
            Carp::croak( sprintf( "Xslate(%s:%d &%s[%d]): %s", $file, $line, $name, $st->{ pc }, $str ) );
        };
    }

    # defaultにできるものは後で直しておく
    $st->tmpl( $tmpl );
    $st->self( $self ); # weak_ref!

    $st->macro( {} );

    $st->sa( undef );
    $st->sb( undef );
    $st->targ( '' );

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $mainframe = Text::Xslate::PP::Opcode::tx_push_frame( $st ); # $st->_push_frame();

    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_RETADDR ] = $len;

    $st->lines( [] );
    $st->{ output } = '';

    $st->code( [] );
    $st->code_len( $len );

    my $code = [];

    for ( my $i = 0; $i < $len; $i++ ) {
        my $pair = $proto->[ $i ];

        unless ( $pair and ref $pair eq 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$pair;
        my $opnum = $TX_OPS->{ $opname };

        unless ( defined $opnum ) {
            Carp::croak( sprintf( "Oops: Unknown opcode '%s' on [%d]", $opname, $i ) );
        }

        $code->[ $i ]->{ exec_code } = $Text::Xslate::PP::Opcode::Opcode_list->[ $opnum ];
        $code->[ $i ]->{ opname }    = $opname; # for test
#        $st->code->[ $i ]->{ exec_code } = $Text::Xslate::PP::Opcode::Opcode_list->[ $opnum ];
#        $st->code->[ $i ]->{ opname } = $opname; # for test

        my $tx_oparg = $Text::Xslate::PP::tx_oparg->[ $opnum ];

        # 後でまとめる
        if ( $tx_oparg & TXARGf_SV ) {

            # This line croak at 'concat'!
            # Carp::croak( sprintf( "Oops: Opcode %s must have an argument on [%d]", $opname, $i ) )
            #     unless ( defined $arg );

            if( $tx_oparg & TXARGf_KEY ) {
#                $st->code->[ $i ]->{ arg } = $arg;
                $code->[ $i ]->{ arg } = $arg;
            }
            elsif ( $tx_oparg & TXARGf_INT ) {
#                $st->code->[ $i ]->{ arg } = $arg;
                $code->[ $i ]->{ arg } = $arg;

                if( $tx_oparg & TXARGf_GOTO ) {
                    my $abs_addr = $i + $arg;

                    if( $abs_addr > $len ) {
                        Carp::croak(
                            sprintf( "Oops: goto address %d is out of range (must be 0 <= addr <= %d)", $arg, $len )
                        );  #これおかしくない？
                    }

#                    $st->code->[ $i ]->{ arg } = $abs_addr;
                    $code->[ $i ]->{ arg } = $abs_addr;
                }

            }
            else {
#                $st->code->[ $i ]->{ arg } = $arg;
                $code->[ $i ]->{ arg } = $arg;
            }

        }
        else {
            if( defined $arg ) {
                Carp::croak( sprintf( "Oops: Opcode %s has an extra argument on [%d]", $opname, $i ) );
            }
#            $st->code->[ $i ]->{ arg } = undef;
            $code->[ $i ]->{ arg } = undef;
        }

        # set up line number
        $st->lines->[ $i ] = $line;

        # special cases
        if( $opnum == $TX_OPS->{ macro_begin } ) {
#            $st->macro->{ $st->code->[ $i ]->{ arg } } = $i;
            $st->macro->{ $code->[ $i ]->{ arg } } = $i;
        }
        elsif( $opnum == $TX_OPS->{ depend } ) {
#            push @{ $tmpl }, $st->code->[ $i ]->{ arg };
            push @{ $tmpl }, $code->[ $i ]->{ arg };
        }

    }
    $st->{code} = $code;
}


sub escaped_string {
    my $str = $_[0];
    bless \$str, 'Text::Xslate::EscapedString';
}


#
# INTERNAL
#


sub tx_load_template {
    my ( $self, $name ) = @_;

    unless ( $self && ref $self ) {
        Carp::croak( "Invalid xslate object" );
    }

    my $ttobj = $self->{ template };
    my $retried = 0;

    unless ( $ttobj and  ref $ttobj eq 'HASH' ) {
        Carp::croak(
            sprintf( "Xslate: Cannot load template '%s': %s", $name, "template table is not a HASH reference" )
        );
    }

    RETRY:

    if( $retried > 1 ) {
        Carp::croak(
            sprintf( "Xslate: Cannot load template '%s': %s", $name, "retried reloading, but failed" )
        );
    }

    unless ( $ttobj->{ $name } ) {
        tx_invoke_load_file( $self, $name );
        $retried++;
        goto RETRY;
    }

    my $tmpl = $ttobj->{ $name };

    my $cache_mtime = $tmpl->[ Text::Xslate::PP::Opcode::TXo_MTIME ];

    return $self->{ tmpl_st }->{ $name } unless $cache_mtime;

    if( $retried > 0 or tx_all_deps_are_fresh( $tmpl, $cache_mtime ) ) {
        return $self->{ tmpl_st }->{ $name };
    }
    else{
        tx_invoke_load_file( $self, $name, $cache_mtime );
        $retried++;
        goto RETRY;
    }

    Carp::croak("Xslate: Cannot load template");
}


sub tx_all_deps_are_fresh {
    my ( $tmpl, $cache_mtime ) = @_;
    my $len = scalar @{$tmpl};

    for ( my $i = Text::Xslate::PP::Opcode::TXo_FULLPATH; $i < $len; $i++ ) {
        my $deppath = $tmpl->[ $i ];

        next unless defined $deppath;

        if ( ( stat( $deppath ) )[9] > $cache_mtime ) {
            my $main_cache = $tmpl->[ Text::Xslate::PP::Opcode::TXo_CACHEPATH ];
            if ( $i != Text::Xslate::PP::Opcode::TXo_FULLPATH and $main_cache ) {
                unlink $main_cache or warn $!;
            }
            return;
        }

    }

    return 1;
}


sub tx_invoke_load_file {
    my ( $self, $name, $mtime ) = @_;
    $self->load_file( $name, $mtime );
}


sub tx_execute { no warnings 'recursion';
    my ( $st, $output, $vars ) = @_;
    my $len = $st->code_len;

    $st->{ output } = '';
    $st->{ pc }     = 0;

    $st->{vars} = $vars;

    local $SIG{__DIE__} = $st->{tmpl}->[ Text::Xslate::PP::Opcode::TXo_ERROR_HANDLER ];
    local $Text::Xslate::PP::Opcode::current_st = $st;
    local $SIG{__WARN__} = $SIG{__DIE__};

    if ( $Depth > 100 ) {
        Carp::croak("Execution is too deep (> 100)");
    }
    $Depth++;

    my $code = $st->{code};

    while( $st->{ pc } < $len ) {
        $code->[ $st->{ pc } ]->{ exec_code }->( $st );
    }

    $st->{targ} = undef;
    $st->{sa} = undef;
    $st->{sb} = undef;


    $Depth--;
}


sub _reset_depth { $Depth = 0; }


sub _make_xslate_escapedstring_class {
    eval q{
        package Text::Xslate::EscapedString;

        sub new {
            my ( $class, $str ) = @_;

            Carp::croak("Usage: Text::Xslate::EscapedString::new(klass, str)") if ( @_ != 2 );

            if ( ref $class ) {
                Carp::croak( sprintf( "You cannot call %s->new() as an instance method", __PACKAGE__ ) );
            }
            elsif ( $class ne __PACKAGE__ ) {
                Carp::croak( sprintf( "You cannot extend %s", __PACKAGE__ ) );
            }
            bless \$str, 'Text::Xslate::EscapedString';
        }

        sub as_string {
            unless ( $_[0] and ref $_[0] ) {
                Carp::croak( sprintf( "You cannot call %s->as_string() a class method", __PACKAGE__ ) );
            }
            return ${ $_[0] };
        }

        use overload (
            '""' => sub { ${ $_[0] } }, # don't use 'as_string' or deep recursion.
            fallback => 1,
        );
    };
    die $@ if $@;
}


1;
__END__

=head1 NAME

Text::Xslate::PP - Text::Xslate compatible pure-Perl module.

=head1 VERSION

This document describes Text::Xslate::PP version 0.001.

  Text::Xslate version 0.1010 compatible

=head1 DESCRIPTION

Text::Xslate compatible pure-Perl module.
Not yet full compatible...

=head1 SEE ALSO

L<Text::Xslate>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
