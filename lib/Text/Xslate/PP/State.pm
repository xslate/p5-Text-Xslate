package Text::Xslate::PP::State; # implement tx_state_t
use Mouse;

use Text::Xslate::Util qw(neat p $DEBUG);
use Text::Xslate::PP;
use Text::Xslate::PP::Const qw(
    TXframe_NAME TXframe_RETADDR TXframe_OUTPUT
    TX_VERBOSE_DEFAULT);

if(!Text::Xslate::PP::_PP_ERROR_VERBOSE()) {
    our @CARP_NOT = qw(
        Text::Xslate::PP::Opcode
        Text::Xslate::PP::Booter
        Text::Xslate::PP::Method
    );
}

has vars => (
    is => 'rw',
);

has tmpl => (
    is => 'rw',
);

has engine => (
    is => 'rw',
    weak_ref => 1,
);

has frame => (
    is => 'rw',
);

has current_frame => (
    is => 'rw',
);

# opinfo is integrated into code
#has info => (
#    is => 'rw',
#);

has code => (
    is  => 'rw',
);

has code_len => (
    is => 'rw',
);

has symbol => (
    is => 'rw',
);

has local_stack => (
    is => 'rw',
);

has encoding => (
    is       => 'ro',
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        require Encode;
        return Encode::find_encoding('UTF-8');
    },
);

sub fetch {
    # my ( $st, $var, $key, $frame, $line ) = @_;
    my $ret;

    if ( Scalar::Util::blessed($_[1]) ) {
        my $key = $_[2];
        $ret = eval { $_[1]->$key() };
        $_[0]->error( [ $_[3], $_[4] ], "%s", $@ ) if $@;
    }
    elsif ( ref $_[1] eq 'HASH' ) {
        if ( defined $_[2] ) {
            $ret = $_[1]->{ $_[2] };
        }
        else {
            $_[0]->warn( [ $_[3], $_[4] ], "Use of nil as a field key" );
        }
    }
    elsif ( ref $_[1] eq 'ARRAY' ) {
        if ( Scalar::Util::looks_like_number($_[2]) ) {
            $ret = $_[1]->[ $_[2] ];
        }
        else {
            $_[0]->warn( [ $_[3], $_[4] ], "Use of %s as an array index", neat( $_[2] ) );
        }
    }
    elsif ( $_[1] ) {
        $_[0]->error( [ $_[3], $_[4] ], "Cannot access %s (%s is not a container)", neat($_[2]), neat($_[1]) );
    }
    else {
        $_[0]->warn( [ $_[3], $_[4] ], "Use of nil to access %s", neat( $_[2] ) );
    }

    return $ret;
}

sub fetch_symbol {
    my ( $st, $name, $context ) = @_;

    my $symbol_table = $st->symbol;
    if ( !exists $symbol_table->{ $name } ) {
        if(defined $context) {
            my($frame, $line) = @{$context};
            if ( defined $line ) {
                $st->{ pc } = $line;
                $st->frame->[ $st->current_frame ]->[ TXframe_NAME ] = $frame;
            }
        }
        Carp::croak( sprintf( "Undefined symbol %s", $name ) );
    }

    return $symbol_table->{ $name };
}

sub localize {
    my($st, $key, $newval) = @_;
    my $vars       = $st->vars;
    my $preeminent = exists $vars->{$key};
    my $oldval     = delete $vars->{$key};

    my $cleanup = $preeminent
        ? sub { $vars->{$key} = $oldval; return }
        : sub { delete $vars->{$key};    return };

    push @{ $st->{local_stack} ||= [] },
        bless($cleanup, 'Text::Xslate::PP::Guard');

    $vars->{$key} = $newval;
    return;
}

sub push_frame {
    my ( $st, $name, $retaddr ) = @_;

    if ( $st->current_frame > 100 ) {
        Carp::croak("Macro call is too deep (> 100)");
    }

    my $new = $st->frame->[ $st->current_frame( $st->current_frame + 1 ) ]
        ||= [];
    $new->[ TXframe_NAME ]    = $name;
    $new->[ TXframe_RETADDR ] = $retaddr;
    return $new;
}

sub pop_frame {
    my( $st, $replace_output ) = @_;
    $st->current_frame( $st->current_frame - 1 );
    if($replace_output) {
        my $top = $st->frame->[ $st->current_frame + 1];
        ($st->{output}, $top->[ TXframe_OUTPUT ])
            = ($top->[ TXframe_OUTPUT ], $st->{output});
    }

    return;
}

sub pad {
    return $_[0]->{frame}->[ $_[0]->{current_frame} ];
}

sub op_arg {
    $_[0]->{ code }->[ $_[0]->{ pc } ]->{ arg };
}

sub print {
    my($st, $sv, $frame_and_line) = @_;
    if ( ref( $sv ) eq Text::Xslate::PP::TXt_RAW ) {
        if(defined ${$sv}) {
            $st->{output} .=
                (utf8::is_utf8($st->{output}) && !utf8::is_utf8(${$sv}))
                 ? eval {$st->encoding->decode(${$sv}, Encode::FB_CROAK())} || ${$sv}
                 : ${$sv};
        }
        else {
            $st->warn($frame_and_line, "Use of nil to print" );
        }
    }
    elsif ( defined $sv ) {
        $sv =~ s/($Text::Xslate::PP::html_metachars)/$Text::Xslate::PP::html_escape{$1}/xmsgeo;
        $st->{output} .=
            (utf8::is_utf8($st->{output}) && !utf8::is_utf8($sv))
             ? eval {$st->encoding->decode($sv, Encode::FB_CROAK())} || $sv
             : $sv;
    }
    else {
        $st->warn( $frame_and_line, "Use of nil to print" );
    }
    return;
}

sub _doerror {
    my ( $st, $context, $fmt, @args ) = @_;
    if(defined $context) { # hack to share it with PP::Booster and PP::Opcode
        my($frame, $line) = @{$context};
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ TXframe_NAME ] = $frame;
        }
    }
    Carp::carp( sprintf( $fmt, @args ) );
    return;
}

sub warn :method {
    my $st = shift;
    if( $st->engine->{verbose} > TX_VERBOSE_DEFAULT ) {
        $st->_doerror(@_);
    }
    return;
}


sub error :method {
    my $st = shift;
    if( $st->engine->{verbose} >= TX_VERBOSE_DEFAULT ) {
        $st->_doerror(@_);
    }
    return;
}

sub bad_arg {
    my $st = shift;
    unshift @_, undef if @_ == 1; # hack to share it with PP::Booster and PP::Opcode
    my($context, $name) = @_;
    return $st->error($context, "Wrong number of arguments for %s", $name);
}

no Mouse;
__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Text::Xslate::PP::State - Text::Xslate pure-Perl virtual machine state

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
