package Text::Xslate::PP::State;

use Any::Moose; # we don't need Any::Moose for this module?

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

has lines => (
    is => 'rw',
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
