package Text::Xslate::PP::Type::Hash;
use Mouse;

{
    package
        Text::Xslate::Type::Hash;
    use Mouse;
    extends 'Text::Xslate::PP::Type::Hash';
    no Mouse;
    __PACKAGE__->meta->make_immutable();
}

use Text::Xslate::PP::Type::Pair;

has [qw(_kv)] => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub{ {} },
);

sub BUILDARGS {
    my $self = shift;
    if(@_ == 1) {
        my($arg) = @_;
        return { _kv => $arg };
    }
    else {
        return $self->BUILDARGS(@_);
    }
}

sub keys :method {
    my($self) = @_;
    return [sort { $a cmp $b } keys %{$self->_kv}];
}

sub values :method {
    my($self) = @_;
    my $kv = $self->_kv;
    return [map { $kv->{$_} } @{ $self->keys } ];
}

sub kv :method {
    my($self) = @_;
    my $kv = $self->_kv;
    return [
        map { Text::Xslate::PP::Type::Pair->new(key => $_, value => $kv->{$_}) }
        @{ $self->keys }
    ];
}

no Mouse;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::PP::Type::Hash - Text::Xslate builtin hash type in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
