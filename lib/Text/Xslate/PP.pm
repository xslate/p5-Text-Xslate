package Text::Xslate::PP;
# Text::Xslate in pure Perl
use 5.008_001;
use strict;

our $VERSION = '0.2010';
$VERSION =~ s/_//; # for developpers versions

BEGIN{
    $ENV{XSLATE} = ($ENV{XSLATE} || '') . '[pp]';
}
use Text::Xslate::Util qw(
    $DEBUG
    p
);

use constant _PP_OPCODE  => scalar($DEBUG =~ /\b pp=opcode  \b/xms);
use constant _PP_BOOSTER => scalar($DEBUG =~ /\b pp=booster \b/xms);
use constant _PP_BACKEND =>   _PP_OPCODE  ? 'Opcode'
                            : _PP_BOOSTER ? 'Booster'
                            :               'Booster'; # default
use constant _PP_ERROR_VERBOSE => scalar($DEBUG =~ /\b pp=verbose \b/xms);

use constant _DUMP_LOAD => scalar($DEBUG =~ /\b dump=load \b/xms);

use Text::Xslate::PP::Const qw(:all);
use Text::Xslate::PP::State;
use Text::Xslate::PP::Type::Raw;
use Text::Xslate ();

use Carp ();

require sprintf('Text/Xslate/PP/%s.pm', _PP_BACKEND);

my $state_class = 'Text::Xslate::PP::' . _PP_BACKEND;

if(_PP_ERROR_VERBOSE) {
    Carp->import('verbose');
}

# fix up @ISA
{
    package
        Text::Xslate;
    if(!our %OPS) {
        # the compiler use %Text::Xslate::OPS in order to optimize the code
        *OPS = \%Text::Xslate::PP::OPS;
    }
    our @ISA = qw(Text::Xslate::PP);
    package
        Text::Xslate::PP;
    our @ISA = qw(Text::Xslate::Engine);
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

sub options {
    my $options  = Text::Xslate::Engine->options;
    $options->{ compiler } = 'Text::Xslate::' . (_PP_BACKEND eq 'Booster' ? 'PP::Compiler' : 'Compiler');
    return $options;
}

#
# public APIs
#

sub render_string {
    my($self, $string, $vars) = @_;
    $self->load_string($string);
    return $self->render('<string>', $vars);
}

sub render {
    my ( $self, $name, $vars ) = @_;

    Carp::croak("Usage: Text::Xslate::render(self, name, vars)")
        if !( @_ == 2 or @_ == 3 );
    unless ( ref $self ) {
        Carp::croak( "Invalid xslate instance" );
    }

    if(!defined $vars) {
        $vars = {};
    }

    if ( !defined $name ) {
        Carp::croak("Xslate: Template name is not given");
    }

    unless ( ref $vars eq 'HASH' ) {
        Carp::croak( sprintf("Xslate: Template variables must be a HASH reference, not %s", $vars ) );
    }

    my $st = tx_load_template( $self, $name, 0 );

    local $_orig_die_handler  = $SIG{__DIE__};
    local $_orig_warn_handler = $SIG{__WARN__};
    local $SIG{__DIE__}       = \&_die;
    local $SIG{__WARN__}      = \&_warn;

    return tx_execute( $st, $vars );
}

sub current_engine {
    return defined($_current_st) ? $_current_st->engine : undef;
}

sub current_file {
    return defined($_current_st)
        ? $_current_st->code->[ $_current_st->{ pc } ]->{file}
        : undef;
}

sub current_line {
    return defined($_current_st)
        ? $_current_st->code->[ $_current_st->{ pc } ]->{line}
        : undef;
}

# >> copied and modified from Text::Xslate

sub _assemble {
    my ( $self, $asm, $name, $fullpath, $cachepath, $mtime ) = @_;

    unless ( defined $name ) { # $name ... filename
        $name = '<string>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    my $st  = $state_class->new();

    if(_PP_BACKEND eq 'Booster'){
        if($asm->[0][0] eq '_ppbooster') {
            my $ppbooster = shift @{$asm};
            $st->{ booster_code } = Text::Xslate::PP::Booster->compile($ppbooster->[1]);
        }
        else {
            Carp::croak("Oops: No booster code: ", p($asm));
        }
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

    my $len = scalar( @$asm );

    my $mainframe = tx_push_frame( $st );
    $mainframe->[ Text::Xslate::PP::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::TXframe_RETADDR ] = $len;

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
        if( $opnum == $OPS{ macro_begin } ) {
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

    push @{$code}, {
        exec_code => $OPCODE[ $OPS{end} ],
        file      => $oi_file,
        line      => $oi_line,
        opname    => 'end',
    }; # for threshold
    return;
}

{
    package
        Text::Xslate::Util;

    sub escaped_string; *escaped_string = \&mark_raw;
    sub mark_raw {
        my($str) = @_;
        if(defined $str) {
            return ref($str) eq Text::Xslate::PP::TXt_RAW()
                ? $str
                : bless \$str, Text::Xslate::PP::TXt_RAW();
        }
        return $str; # undef
    }
    sub unmark_raw {
        my($str) = @_;
        return ref($str) eq Text::Xslate::PP::TXt_RAW()
            ? ${$str}
            : $str;
    }

    sub html_escape {
        my($s) = @_;
        return $s if
            ref($s) eq Text::Xslate::PP::TXt_RAW()
            or !defined($s);

        $s =~ s/($html_metachars)/$html_escape{$1}/xmsgeo;
        return bless \$s, Text::Xslate::PP::TXt_RAW();
    }

    my $uri_unsafe_rfc3986 = qr/[^A-Za-z0-9\-\._~]/;
    sub uri_escape {
        my($s) = @_;
        return $s if not defined $s;
        # XXX: This must be the same as uri_escape() in XS.
        #      See also tx_uri_escape() in xs/Text-Xslate.xs.
        utf8::encode($s) if utf8::is_utf8($s);
        $s =~ s/($uri_unsafe_rfc3986)/sprintf '%%' . '%02X', ord $1/xmsgeo;
        return $s;
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

sub tx_concat {
    my($lhs, $rhs) = @_;
    if(ref($lhs) eq TXt_RAW) {
        if(ref($rhs) eq TXt_RAW) {
            return Text::Xslate::Util::mark_raw(${ $lhs } . ${ $rhs });
        }
        else {
            return Text::Xslate::Util::mark_raw(${ $lhs } . Text::Xslate::Util::html_escape($rhs));
        }
    }
    else {
        if(ref($rhs) eq TXt_RAW) {
            return Text::Xslate::Util::mark_raw(Text::Xslate::Util::html_escape($lhs) . ${ $rhs });
        }
        else {
            return $lhs . $rhs;
        }
    }
}

sub tx_repeat {
    my($lhs, $rhs) = @_;
    if(!defined($lhs)) {
        $_current_st->warn(undef, "Use of nil for repeat operator");
    }
    elsif(!Scalar::Util::looks_like_number($rhs)) {
        $_current_st->error(undef, "Repeat count must be a number, not %s",
            Text::Xslate::Util::neat($rhs));
        return undef;
    }
    else {
        if( ref( $lhs ) eq TXt_RAW ) {
            return Text::Xslate::Util::mark_raw( Text::Xslate::Util::unmark_raw($lhs) x $rhs );
        }
        else {
            return $lhs x $rhs;
        }
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
    my ( $self, $name, $from_include ) = @_;

    unless ( ref $self ) {
        Carp::croak( "Invalid xslate instance" );
    }

    my $ttable = $self->{ template };
    my $retried = 0;

    if(ref $ttable ne 'HASH' ) {
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

    if ( not exists $ttable->{ $name } ) {
        $self->load_file( $name, undef, $from_include );
        $retried++;
        goto RETRY;
    }

    my $tmpl = $ttable->{ $name };

    if(ref($tmpl) ne 'ARRAY' or not exists $self->{tmpl_st}{$name}) {
        Carp::croak(
            sprintf( "Xslate: Cannot load template '%s': template entry is invalid", $name ),
        );
    }

    my $cache_mtime = $tmpl->[ TXo_MTIME ];

    if(not defined $cache_mtime) { # cache => 2 (release mode)
        return $self->{ tmpl_st }->{ $name };
    }

    if( $retried > 0 or tx_all_deps_are_fresh( $tmpl, $cache_mtime ) ) {
        return $self->{ tmpl_st }->{ $name };
    }
    else{
        $self->load_file( $name, $cache_mtime, $from_include );
        $retried++;
        goto RETRY;
    }

    Carp::croak("Oops: Not reached");
}


sub tx_all_deps_are_fresh {
    my ( $tmpl, $cache_mtime ) = @_;
    my $len = scalar @{$tmpl};

    for ( my $i = TXo_FULLPATH; $i < $len; $i++ ) {
        my $deppath = $tmpl->[ $i ];

        next if ref $deppath;

        my $mtime = ( stat( $deppath ) )[9];
        if ( defined($mtime) and $mtime > $cache_mtime ) {
            my $main_cache = $tmpl->[ TXo_CACHEPATH ];
            if ( $i != TXo_FULLPATH and $main_cache ) {
                unlink $main_cache or warn $!;
            }
            if(_DUMP_LOAD) {
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

    if ( _PP_BACKEND eq 'Booster' ) {
        if(_PP_ERROR_VERBOSE and ref $st->{ booster_code } ne 'CODE') {
            Carp::croak("Oops: Not a CODE reference: "
                . Text::Xslate::Util::neat($st->{ booster_code }));
        }
        return $st->{ booster_code }->( $st );
    }
    else {
        if(_PP_ERROR_VERBOSE and ref $st->{code}->[0]->{ exec_code } ne 'CODE') {
            Carp::croak("Oops: Not a CODE reference: "
                . Text::Xslate::Util::neat($st->{code}->[0]->{ exec_code }));
        }

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

    if(!_PP_ERROR_VERBOSE && $str =~ s/at .+Text.Xslate.PP.+ line \d+\.\n$//) {
        $str = Carp::shortmess($str);
    }

    Carp::croak( $str ) unless defined $st;

    my $engine = $st->engine;

    my $cframe = $st->frame->[ $st->current_frame ];
    my $name   = $cframe->[ Text::Xslate::PP::TXframe_NAME ];

    my $opcode = $st->code->[ $st->{ pc } ];
    my $file   = $opcode->{file};
    if($file eq '<string>' && exists $engine->{string_buffer}) {
        $file = \$engine->{string_buffer};
    }

    my $mess   = Text::Xslate::Util::make_error($engine, $str, $file, $opcode->{line},
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

This document describes Text::Xslate::PP version 0.2010.

=head1 DESCRIPTION

This module implements Text::Xslate runtime engine in pure Perl.
Normally it will be loaded if it fails to load XS. So you do not need
to use this module explicitly.

    # Text::Xslate loads PP if needed
    use Text::Xslate;
    my $tx = Text::Xslate->new();

If you want to use Text::Xslate::PP, however, you can use it.

    use Text::Xslate::PP;
    my $tx = Text::Xslate->new();

XS/PP mode might be switched with C<< $ENV{XSLATE} = 'pp' or 'xs' >>.

From 0.1024 on, there are two pure Perl engines.
C<Text::Xslate::PP::Booster>, enabled by C<< $ENV{XSLATE} = 'pp=booster' >>,
generates optimized Perl code from intermediate code.
C<Text::Xlsate::PP::Opcode>, enabled by C<< $ENV{XSLATE} = 'pp=opcode' >>,
executes intermediate code directly, emulating the virtual machine in pure Perl.

PP::Booster is much faster than PP::Opcode, but it may be less stable.
The default pure Perl engine is B<PP::Booster>, so if you run into problems,
please try C<< $ENV{XSLATE} = 'pp=opcode' >>.

C<< $ENV{XSLATE} = 'pp=verbose' } >> may be useful for debugging.

=head1 NOTE

=head2 Performance

There might be cases where you cannot use XS modules.

Here is a result of F<benchmark/x-poor-env.pl> to compare pure Perl template
engines in poor environment where applications runs as CGI scripts and XS
modules are not available.

    $ perl -Mblib benchmark/x-poor-env.pl
    Perl/5.10.1 i686-linux
    Xslate backend: Booster
    Text::Xslate/0.1058
    Template/2.22
    HTML::Template/2.9
    Text::MicroTemplate/0.15
    Text::MicroTemplate::Extended/0.11
    1..3
    ok 1 - TT: Template-Toolkit
    ok 2 - MT: Text::MicroTemplate
    ok 3 - HT: HTML::Template
    Benchmarks with 'include' (datasize=100)
             Rate     TT     HT Xslate     MT
    TT     76.1/s     --   -60%   -61%   -82%
    HT      189/s   149%     --    -3%   -56%
    Xslate  196/s   158%     4%     --   -54%
    MT      429/s   463%   126%   118%     --

According to this result, PP::Booster is over 2 times faster than Template::Toolkit,
and as fast as HTML::Template, but slower than Text::MicroTemplate.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP::Opcode>

L<Text::Xslate::PP::Booster>

=head1 AUTHOR

Text::Xslate::PP stuff is originally written by Makamaka Hannyaharamitu
E<lt>makamaka at cpan.orgE<gt>, and also maintained by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
