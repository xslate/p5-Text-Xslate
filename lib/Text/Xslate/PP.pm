package Text::Xslate::PP;
# Text::Xslate in pure Perl
use 5.008_001;
use strict;

our $VERSION = '0.1041';

BEGIN{
    $ENV{XSLATE} = ($ENV{XSLATE} || '') . '[pp]';
}

use Text::Xslate::PP::Const;
use Text::Xslate::PP::State;
use Text::Xslate::PP::Type::Raw;
use Text::Xslate::Util qw($DEBUG p make_error);
use Text::Xslate;

use Carp ();

use constant _PP_OPCODE  => scalar($DEBUG =~ /\b pp=opcode  \b/xms);
use constant _PP_BOOSTER => scalar($DEBUG =~ /\b pp=booster \b/xms);

use constant _PP_BACKEND =>   _PP_OPCODE  ? 'Opcode'
                            : _PP_BOOSTER ? 'Booster'
                            :               'Opcode'; # default

use constant _DUMP_LOAD_TEMPLATE => scalar($DEBUG =~ /\b dump=load_file \b/xms);


require sprintf('Text/Xslate/PP/%s.pm', _PP_BACKEND);

my $state_class = 'Text::Xslate::PP::' . _PP_BACKEND;

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

our $_depth = 0;
our $_current_st;

our($_orig_die_handler, $_orig_warn_handler);

our %html_escape = (
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    "'" => '&apos;',
);
our $html_metachars = sprintf '[%s]', join '', map { quotemeta } keys %html_escape;

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
        $name = '<string>';
    }

    unless ( ref $vars eq 'HASH' ) {
        Carp::croak( sprintf("Xslate: Template variables must be a HASH reference, not %s", $vars ) );
    }

    my $st = tx_load_template( $self, $name );

    local $_orig_die_handler  = $SIG{__DIE__};
    local $_orig_warn_handler = $SIG{__WARN__};
    local $SIG{__DIE__}       = \&_die;
    local $SIG{__WARN__}      = \&_warn;

    return tx_execute( $st, $vars );
}

sub engine {
    return defined($_current_st) ? $_current_st->engine : undef;
}

sub _assemble {
    my ( $self, $proto, $name, $fullpath, $cachepath, $mtime ) = @_;
    my $len = scalar( @$proto );
    my $st  = $state_class->new();

    our %OPS;    # defined in Text::Xslate::PP::Const
    our @OPARGS; # defined in Text::Xslate::PP::Const

    unless ( defined $name ) { # $name ... filename
        $name = '<string>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    $st->symbol({ %{$self->{ function }} });

    my $tmpl = [];

    $self->{ template }->{ $name } = $tmpl;
    $self->{ tmpl_st }->{ $name }  = $st;

    $tmpl->[ Text::Xslate::PP::TXo_MTIME ]     = $mtime;
    $tmpl->[ Text::Xslate::PP::TXo_CACHEPATH ] = $cachepath;
    $tmpl->[ Text::Xslate::PP::TXo_FULLPATH ]  = $fullpath;

    $st->tmpl( $tmpl );
    $st->engine( $self ); # weak_ref!

    $st->{sa}   = undef;
    $st->{sb}   = undef;

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $mainframe = tx_push_frame( $st );

    $mainframe->[ Text::Xslate::PP::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::TXframe_RETADDR ] = $len;

    $st->code_len( $len );

    my $code = $st->code([]);
    my $macro;

    my $oi_line = -1;
    my $oi_file = $name;
    for ( my $i = 0; $i < $len; $i++ ) {
        my $c = $proto->[ $i ];

        if ( ref $c ne 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line, $file ) = @{$c};
        my $opnum = $OPS{ $opname };

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

        if(_PP_BACKEND eq 'Opcode') {
            $code->[ $i ]->{ exec_code } = $OPCODE[ $opnum ];
        }

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

        # special cases
        if( $opnum == $OPS{ macro_begin } ) {
            my $name = $code->[ $i ]->{ arg };
            if(!exists $st->symbol->{$name}) {
                require Text::Xslate::PP::Macro;
                $macro = Text::Xslate::PP::Macro->new(
                    name => $name,
                    addr => $i,
                );
                $st->symbol->{ $name } = $macro;
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
        if _PP_BACKEND eq 'Booster';

    push @{$code}, { exec_code => $OPCODE[ $OPS{end} ] }; # for threshold
    return;
}

{
    package
        Text::Xslate::Util;

    my $esc_class = 'Text::Xslate::Type::Raw';
    sub escaped_string; *escaped_string = \&mark_raw;
    sub mark_raw {
        my($str) = @_;
        return ref($str) eq $esc_class
            ? $str
            : bless \$str, $esc_class;
    }
    sub unmark_raw {
        my($str) = @_;
        return ref($str) eq $esc_class
            ? ${$str}
            : $str;
    }

    sub html_escape {
        my($s) = @_;
        return $s if
            ref($s) eq $esc_class
            or !defined($s);

        $s =~ s/($html_metachars)/$html_escape{$1}/xmsgeo;
        return bless \$s, $esc_class;
    }
}

#
# INTERNAL
#

sub tx_sv_eq {
    my($x, $y) = @_;
    if ( defined $x ) {
        return defined $y && $x eq $y;
    }
    else {
        return !defined $y;
    }
}

sub tx_match { # simple smart matching
    my($x, $y) = @_;

    if(ref($y) eq 'ARRAY') {
        foreach my $item(@{$y}) {
            if(defined($item)) {
                if(defined($x) && $x eq $item) {
                    return 1;
                }
            }
            else {
                if(not defined($x)) {
                    return 1;
                }
            }
        }
        return '';
    }
    elsif(ref($y) eq 'HASH') {
        return defined($x) && exists $y->{$x};
    }
    elsif(defined($y)) {
        return defined($x) && $x eq $y;
    }
    else {
        return !defined($x);
    }
}

sub tx_push_frame {
    my ( $st ) = @_;

    if ( $st->current_frame > 100 ) {
        Carp::croak("Macro call is too deep (> 100)");
    }

    return $st->frame->[ $st->current_frame( $st->current_frame + 1 ) ] ||= [];
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

    my $cache_mtime = $tmpl->[ TXo_MTIME ];

    if(not defined $cache_mtime) { # cache => 2 (release mode)
        return $self->{ tmpl_st }->{ $name };
    }

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

    for ( my $i = TXo_FULLPATH; $i < $len; $i++ ) {
        my $deppath = $tmpl->[ $i ];

        next unless defined $deppath;

        my $mtime = ( stat( $deppath ) )[9];
        if ( $mtime > $cache_mtime ) {
            my $main_cache = $tmpl->[ TXo_CACHEPATH ];
            if ( $i != TXo_FULLPATH and $main_cache ) {
                unlink $main_cache or warn $!;
            }
            if(_DUMP_LOAD_TEMPLATE) {
                printf STDERR "  tx_all_depth_are_fresh: %s is too old (%d > %d)\n",
                    $deppath, $mtime, $cache_mtime;
            }
            return 0;
        }

    }

    return 1;
}

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
        local $st->{sa};
        local $st->{sb};
        $st->{output} = '';
        $st->{code}->[0]->{ exec_code }->( $st );
        return $st->{output};
    }
}


sub _error_handler {
    my ( $str, $die ) = @_;
    my $st = $_current_st;

    local $SIG{__WARN__} = $_orig_warn_handler;
    local $SIG{__DIE__}  = $_orig_die_handler;

    if($str =~ s/at .+Text.Xslate.PP.+ line \d+\.\n$//) {
        $str = Carp::shortmess($str);
    }

    Carp::croak( $str ) unless $st;

    my $engine = $st->engine;

    my $cframe = $st->frame->[ $st->current_frame ];
    my $name   = $cframe->[ Text::Xslate::PP::TXframe_NAME ];

    my $opcode = $st->code->[ $st->{ pc } ];
    my $file   = $opcode->{file};
    if($file eq '<string>' && exists $engine->{string_buffer}) {
        $file = \$engine->{string_buffer};
    }

    my $mess   = make_error($engine, $str, $file, $opcode->{line},
        sprintf( "&%s[%d]", $name, $st->{pc} ));

    if ( !$die ) {
        # $h can ignore warnings
        if ( my $h = $engine->{ warn_handler } ) {
            $h->( $mess );
        }
        else {
            warn $mess;
        }
    }
    else {
        # $h cannot ignore errors
        if(my $h = $engine->{ die_handler } ) {
            $h->( $mess );
        }
        die $mess; # MUST DIE!
    }
    return;
}

sub _warn {
    _error_handler( $_[0], 0 );
}

sub _die {
    _error_handler( $_[0], 1 );
}

{
    package
        Text::Xslate::PP::Guard;

    sub DESTROY { $_[0]->() }
}

1;
__END__

=head1 NAME

Text::Xslate::PP - Yet another Text::Xslate runtime in pure Perl

=head1 VERSION

This document describes Text::Xslate::PP version 0.1041.

=head1 DESCRIPTION

This module implements Text::Xslate runtime engine in pure Perl.
Normally it will be loaded if it fails to load XS. So you don't need
to use this module explicitly.

    # Text::Xslate loads PP if needed
    use Text::Xslate;
    my $tx = Text::Xslate->new();

If you want to use Text::Xslate::PP, however, you can use it.

    use Text::Xslate::PP;
    my $tx = Text::Xslate->new();

XS/PP mode might be switched with C<< $ENV{XSLATE} = 'pp' or 'xs' >>.

From 0.1024 on, there are two pure Perl engines.
C<Text::Xslate::PP::Booster>, used with C<< $ENV{XSLATE} = 'pp=booster' >>,
generates optimized Perl code from intermediate code.
C<Text::Xlsate::PP::Opcode>, used with C<< $ENV{XSLATE = 'pp=opcode' >>,
execute intermediate code directly, emulating the virtual machine in pure Perl.

PP::Booster is much faster than PP::Opcode, but it is less stable,
so the default pure Perl engine is B<PP::Opcode>, but PP::Booster will be
the default in a future if it is stable enough.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP::Opcode>

L<Text::Xslate::PP::Booster>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
