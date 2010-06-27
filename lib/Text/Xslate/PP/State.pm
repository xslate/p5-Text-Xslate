package Text::Xslate::PP::State;

use Any::Moose; # we don't need Any::Moose for this module?

our @CARP_NOT = qw(
    Text::Xslate::PP::Opcode
    Text::Xslate::PP::Booter
    Text::Xslate::PP::Method
);

use Text::Xslate::PP::Const ();

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

sub pad {
    my($st) = @_;
    return $st->frame->[ $st->current_frame ];
}

sub op_arg {
    $_[0]->{ code }->[ $_[0]->{ pc } ]->{ arg };
}


sub _verbose {
    my $v = $_[0]->engine->{ verbose };
    defined $v ? $v : Text::Xslate::PP::TX_VERBOSE_DEFAULT;
}

sub _doerror {
    my ( $st, $context, $fmt, @args ) = @_;
    if(defined $context) { # hack to share it with PP::Booster and PP::Opcode
        my($frame, $line) = @{$context};
        if ( defined $line ) {
            $st->{ pc } = $line;
            $st->frame->[ $st->current_frame ]->[ Text::Xslate::PP::TXframe_NAME ] = $frame;
        }
    }
    Carp::carp( sprintf( $fmt, @args ) );
    return;
}

sub warn :method {
    my $st = shift;
    if( $st->_verbose > Text::Xslate::PP::TX_VERBOSE_DEFAULT ) {
        $st->_doerror(@_);
    }
    return;
}


sub error :method {
    my $st = shift;
    if( $st->_verbose >= Text::Xslate::PP::TX_VERBOSE_DEFAULT ) {
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

no Any::Moose;
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
