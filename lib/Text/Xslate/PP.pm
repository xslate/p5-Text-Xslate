package Text::Xslate::PP;

use 5.008;
use strict;

use parent qw(Exporter);
our @EXPORT_OK;
our @EXPORT;

use Carp ();
use Data::Dumper;

use Text::Xslate::PP::Const;
use Text::Xslate::PP::State;

my $TX_OPS = \%Text::Xslate::OPS;

$Text::Xslate::PP::Depth = 0;

our $VERSION = '0.1000';

our $XS_COMAPT_VERSION = '0.1013';

my $loaded;

unless ( $loaded++ ) {
    my $called_by = caller;

    if ( $called_by->isa('Text::Xslate') ) {
        @EXPORT = qw( _initialize render ); # for Text::Xslate
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
# export API
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

    local $SIG{__DIE__}  = \&_die;
    local $SIG{__WARN__} = \&_warn;

    tx_execute( $st, undef, $vars );

    $st->{ output };
}


sub _initialize {
    my ( $self, $proto, $name, $fullpath, $cachepath, $mtime ) = @_;
    my $len = scalar( @$proto );
    my $st  = Text::Xslate::PP::State->new;

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

    $st->tmpl( $tmpl );
    $st->self( $self ); # weak_ref!

    $st->macro( {} );

    $st->{sa}   = undef;
    $st->{sb}   = undef;
    $st->{targ} = '';

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $mainframe = Text::Xslate::PP::Opcode::tx_push_frame( $st );

    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_RETADDR ] = $len;

    $st->lines( [] );
    $st->{ output } = '';

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

        my $tx_oparg = $Text::Xslate::PP::tx_oparg->[ $opnum ];

        # 後でまとめる
        if ( $tx_oparg & TXARGf_SV ) {

            # This line croak at 'concat'!
            # Carp::croak( sprintf( "Oops: Opcode %s must have an argument on [%d]", $opname, $i ) )
            #     unless ( defined $arg );

            if( $tx_oparg & TXARGf_KEY ) {
                $code->[ $i ]->{ arg } = $arg;
            }
            elsif ( $tx_oparg & TXARGf_INT ) {
                $code->[ $i ]->{ arg } = $arg;

                if( $tx_oparg & TXARGf_GOTO ) {
                    my $abs_addr = $i + $arg;

                    if( $abs_addr > $len ) {
                        Carp::croak(
                            sprintf( "Oops: goto address %d is out of range (must be 0 <= addr <= %d)", $arg, $len )
                        );  #これおかしくない？
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

        # set up line number
        $st->lines->[ $i ] = $line;

        # special cases
        if( $opnum == $TX_OPS->{ macro_begin } ) {
            $st->macro->{ $code->[ $i ]->{ arg } } = $i;
        }
        elsif( $opnum == $TX_OPS->{ depend } ) {
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

    local $Text::Xslate::PP::Opcode::current_st = $st;

    if ( $Text::Xslate::PP::Depth > 100 ) {
        Carp::croak("Execution is too deep (> 100)");
    }

    local $Text::Xslate::PP::Depth = $Text::Xslate::PP::Depth + 1;

    $st->{code}->[ 0 ]->{ exec_code }->( $st );

    $st->{targ} = undef;
    $st->{sa}   = undef;
    $st->{sb}   = undef;
}


sub _error_handler {
    my ( $str, $die_handler ) = @_;
    my $st = $Text::Xslate::PP::Opcode::current_st;

    Carp::croak( 'Not in $xslate->render()' ) unless $st;

    my $cframe = $st->frame->[ $st->current_frame ];
    my $name   = $cframe->[ Text::Xslate::PP::Opcode::TXframe_NAME ];

    $Text::Xslate::PP::Depth = 0;

    #    /* unroll the stack frame */
    #    /* to fix TXframe_OUTPUT */

    my $file = $st->tmpl->[ Text::Xslate::PP::Opcode::TXo_NAME ];
    my $line = $st->lines->[ $st->{ pc } ] || 0;
    my $mess = sprintf( "Xslate(%s:%d &%s[%d]): %s", $file, $line, $name, $st->{ pc }, $str );

    if ( $die_handler ) {
        Carp::croak( $mess );
    }
    else {

    if ( my $h = $st->self->{ warn_handler } ) {
        $h->( $mess );
    }
    else {
        Carp::carp( $mess );
    }

    }

}


sub _die {
    _error_handler( $_[0], 1 );
}


sub _warn {
    _error_handler( $_[0], 0 );
}


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

This document describes Text::Xslate::PP version 0.1000.

=head1 DESCRIPTION

This module exports L<Text::Xslate> compatible pure-Perl APIs.
Normally it is called in Text::Xslate. So you don't need
to use this module in your application although it can be called directly.

    # Text::Xslate calls PP when it fails to install XS.
    use Text::Xslate;
    my $tx = Text::Xslate->new();
    
    # direct use...
    use Text::Xslate::PP;
    my $tx_pp = Text::Xslate::PP->new();

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
