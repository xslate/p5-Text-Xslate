package Text::Xslate::PP;
# Text::Xslate in pure Perl
use 5.008_001;
use strict;

our $VERSION = '0.1030';

BEGIN{
    $ENV{XSLATE} = ($ENV{XSLATE} || '') . '[pp]';
}

use Text::Xslate::PP::Const;
use Text::Xslate::PP::State;
use Text::Xslate::PP::EscapedString;
use Text::Xslate::Util qw($DEBUG p);

use Carp ();

use constant _PP_OPCODE  => scalar($DEBUG =~ /\b pp=opcode  \b/xms);
use constant _PP_BOOSTER => scalar($DEBUG =~ /\b pp=booster \b/xms);

use constant _PP_BACKEND =>   _PP_OPCODE  ? 'Opcode'
                            : _PP_BOOSTER ? 'Booster'
                            :               'Opcode'; # default

require sprintf('Text/Xslate/PP/%s.pm', _PP_BACKEND);

our @OPCODE; # defined in PP::Const

{
    package
        Text::Xslate;
    if(!our %OPS) {
        # the compiler use %Text::Xslate::OPS in order to optimize the code
        *OPS = \%Text::Xslate::PP::OPS;
    }
    unshift our @ISA, 'Text::Xslate::PP';
}


sub compiler_class() { 'Text::Xslate::Compiler' }

#
# public APIs
#

sub render_string {
    my($self, $string, $vars) = @_;
    $self->load_string($string);
    return $self->render(undef, $vars);
}

sub render {
    my ( $self, $name, $vars ) = @_;

    Carp::croak("Usage: Text::Xslate::render(self, name, vars)")
        if !( @_ == 2 or @_ == 3 );

    if(!defined $vars) {
        $vars = {};
    }

    if ( !defined $name ) {
        $name = '<input>';
    }

    unless ( ref $vars eq 'HASH' ) {
        Carp::croak( sprintf("Xslate: Template variables must be a HASH reference, not %s", $vars ) );
    }

    my $st = tx_load_template( $self, $name );

    local $SIG{__DIE__}  = \&_die;
    local $SIG{__WARN__} = \&_warn;

    return tx_execute( $st, $vars );
}


sub _assemble {
    my ( $self, $proto, $name, $fullpath, $cachepath, $mtime ) = @_;
    my $len = scalar( @$proto );
    my $st  = Text::Xslate::PP::State->new;

    our %OPS;    # defined in Text::Xslate::PP::Const
    our @OPARGS; # defined in Text::Xslate::PP::Const

    unless ( defined $name ) { # $name ... filename
        $name = '<input>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    $st->function({ %{$self->{ function }} });

    my $tmpl = [];

    $self->{ template }->{ $name } = $tmpl;
    $self->{ tmpl_st }->{ $name }  = $st;

    $tmpl->[ Text::Xslate::PP::TXo_NAME ]      = $name;
    $tmpl->[ Text::Xslate::PP::TXo_MTIME ]     = $mtime;
    $tmpl->[ Text::Xslate::PP::TXo_CACHEPATH ] = $cachepath;
    $tmpl->[ Text::Xslate::PP::TXo_FULLPATH ]  = $fullpath;

    $st->tmpl( $tmpl );
    $st->self( $self ); # weak_ref!

    $st->{sa}   = undef;
    $st->{sb}   = undef;

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $mainframe = tx_push_frame( $st );

    $mainframe->[ Text::Xslate::PP::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::TXframe_RETADDR ] = $len;

    $st->lines( [] );

    $st->code_len( $len );

    my $code = [];
    my $macro;

    for ( my $i = 0; $i < $len; $i++ ) {
        my $pair = $proto->[ $i ];

        unless ( $pair and ref $pair eq 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$pair;
        my $opnum = $OPS{ $opname };

        unless ( defined $opnum ) {
            Carp::croak( sprintf( "Oops: Unknown opcode '%s' on [%d]", $opname, $i ) );
        }

        $code->[ $i ]->{ exec_code } = $OPCODE[ $opnum ]
            if !_PP_BOOSTER;
        $code->[ $i ]->{ opname }    = $opname; # for test

        my $oparg = $OPARGS[ $opnum ];

        if ( $oparg & TXARGf_SV ) {

            # This line croak at 'concat'!
            # Carp::croak( sprintf( "Oops: Opcode %s must have an argument on [%d]", $opname, $i ) )
            #     unless ( defined $arg );

            if( $oparg & TXARGf_KEY ) {
                $code->[ $i ]->{ arg } = $arg;
            }
            elsif ( $oparg & TXARGf_INT ) {
                $code->[ $i ]->{ arg } = int($arg);

                if( $oparg & TXARGf_GOTO ) {
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

        # set up line number
        $st->lines->[ $i ] = $line;

        # special cases
        if( $opnum == $OPS{ macro_begin } ) {
            my $name = $code->[ $i ]->{ arg };
            if(!exists $st->function->{$name}) {
                require Text::Xslate::PP::Macro;
                $macro = Text::Xslate::PP::Macro->new(
                    name => $name,
                    addr => $i,
                );
                $st->function->{ $name } = $macro;
            }
            else {
                $macro = undef;
            }
        }
        elsif( $opnum == $OPS{ macro_nargs } ) {
            if($macro) {
                $macro->nargs($code->[$i]->{arg});
            }
        }
        elsif( $opnum == $OPS{ macro_outer } ) {
            if($macro) {
                $macro->outer($code->[$i]->{arg});
            }
        }
        elsif( $opnum == $OPS{ depend } ) {
            push @{ $tmpl }, $code->[ $i ]->{ arg };
        }

    }

    $st->{ booster_code } = Text::Xslate::PP::Booster->new()->opcode_to_perlcode( $proto )
        if _PP_BOOSTER;

    $st->{ code } = $code;
    return;
}

{
    package
        Text::Xslate::Util;

    sub escaped_string {
        my $str = $_[0];
        bless \$str, 'Text::Xslate::EscapedString';
    }

    sub html_escape {
        my($s) = @_;
        return $s if
            ref($s) eq 'Text::Xslate::EscapedString'
            or !defined($s);

        $s =~ s/&/&amp;/g;
        $s =~ s/</&lt;/g;
        $s =~ s/>/&gt;/g;
        $s =~ s/"/&quot;/g; # " for poor editors
        $s =~ s/'/&apos;/g; # ' for poor editors

        return escaped_string($s);
    }
}

#
# INTERNAL
#

sub tx_push_frame {
    my ( $st ) = @_;

    if ( $st->current_frame > 100 ) {
        Carp::croak("Macro call is too deep (> 100)");
    }

    $st->current_frame( $st->current_frame + 1 );

    $st->frame->[ $st->current_frame ] ||= [];

    $st->pad( $st->frame->[ $st->current_frame ] );

    $st->frame->[ $st->current_frame ];
}



sub tx_load_template {
    my ( $self, $name ) = @_;

    unless ( ref $self ) {
        Carp::croak( "Invalid xslate instance" );
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
        $self->load_file( $name );
        $retried++;
        goto RETRY;
    }

    my $tmpl = $ttobj->{ $name };

    my $cache_mtime = $tmpl->[ Text::Xslate::PP::TXo_MTIME ];

    return $self->{ tmpl_st }->{ $name } unless $cache_mtime;

    if( $retried > 0 or tx_all_deps_are_fresh( $tmpl, $cache_mtime ) ) {
        return $self->{ tmpl_st }->{ $name };
    }
    else{
        $self->load_file( $name, $cache_mtime );
        $retried++;
        goto RETRY;
    }

    Carp::croak("Xslate: Cannot load template");
}


sub tx_all_deps_are_fresh {
    my ( $tmpl, $cache_mtime ) = @_;
    my $len = scalar @{$tmpl};

    for ( my $i = Text::Xslate::PP::TXo_FULLPATH; $i < $len; $i++ ) {
        my $deppath = $tmpl->[ $i ];

        next unless defined $deppath;

        if ( ( stat( $deppath ) )[9] > $cache_mtime ) {
            my $main_cache = $tmpl->[ Text::Xslate::PP::TXo_CACHEPATH ];
            if ( $i != Text::Xslate::PP::TXo_FULLPATH and $main_cache ) {
                unlink $main_cache or warn $!;
            }
            return;
        }

    }

    return 1;
}

our $_depth = 0;
our $_current_st;

sub tx_execute { 
    my ( $st, $vars ) = @_;
    no warnings 'recursion';

    if ( $_depth > 100 ) {
        Carp::croak("Execution is too deep (> 100)");
    }

    $st->{pc}   = 0;
    $st->{vars} = $vars;

    local $_depth      = $_depth + 1;
    local $_current_st = $st;

    local $st->{local_stack};
    local $st->{SP} = [];

    if ( $st->{ booster_code } ) {
        return $st->{ booster_code }->( $st );
    }
    else {
        local $st->{targ};
        local $st->{sa};
        local $st->{sb};
        local $st->{SP} = [];
        $st->{output} = '';
        $st->{code}->[0]->{ exec_code }->( $st );
        return $st->{output};
    }
}


sub _error_handler {
    my ( $str, $die ) = @_;
    my $st = $_current_st;

    if($str =~ s/at .+Text.Xslate.PP.+ line \d+\.\n$//) {
        $str = Carp::shortmess($str);
    }

    Carp::croak( 'Not in $xslate->render()' ) unless $st;

    my $cframe = $st->frame->[ $st->current_frame ];
    my $name   = $cframe->[ Text::Xslate::PP::TXframe_NAME ];

    if( $die ) {
        $_depth = 0;
    }

    my $file = $st->tmpl->[ Text::Xslate::PP::TXo_NAME ];
    my $line = $st->lines->[ $st->{ pc } ] || 0;
    my $mess = sprintf( "Xslate(%s:%d &%s[%d]): %s", $file, $line, $name, $st->{ pc }, $str );

    if ( !$die ) { # warn
        # $h can ignore warnings
        if ( my $h = $st->self->{ warn_handler } ) {
            $h->( $mess );
        }
        else {
            Carp::carp( $mess );
        }
    }
    else { # die
        # $h cannot ignore errors
        if(my $h = $st->self->{ die_handler } ) {
            $h->( $mess );
        }
        Carp::croak( $mess ); # MUST DIE!
    }
    return;
}


sub _die {
    _error_handler( $_[0], 1 );
}


sub _warn {
    _error_handler( $_[0], 0 );
}


1;
__END__

=head1 NAME

Text::Xslate::PP - Yet another Text::Xslate runtime in pure Perl

=head1 VERSION

This document describes Text::Xslate::PP version 0.1030.

=head1 DESCRIPTION

This module implements L<Text::Xslate> runtime in pure Perl.
Normally it will be loaded in Text::Xslate if needed. So you don't need
to use this module in your applications.

    # Text::Xslate calls PP when it fails to load XS.
    use Text::Xslate;
    my $tx = Text::Xslate->new();

If you want to use Text::Xslate::PP, however, you can use it.

    use Text::Xslate::PP;
    my $tx = Text::Xslate->new();

XS/PP mode might be switched with C<< $ENV{XSLATE} = 'pp' or 'xs' >>.

From 0.1024 on, two pure Perl engines are implemented.
C<Text::Xslate::PP::Booster>, which is the default, generates optimized
Perl code from intermediate code.
C<Text::Xlsate::PP::Opcode> emulates the virtual machine in pure Perl,
available with C<< $ENV{XSLATE} = 'pp=opcode' >>.

=head1 SEE ALSO

L<Text::Xslate::PP::Opcode>

L<Text::Xslate::PP::Booster>

L<Text::Xslate>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
