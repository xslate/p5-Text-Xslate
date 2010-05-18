package Text::Xslate::PP::Type::Array;
use Mouse;

{
    package
        Text::Xslate::Type::Array;
    use Mouse;
    extends 'Text::Xslate::PP::Type::Array';
    no Mouse;
    __PACKAGE__->meta->make_immutable();
}

use Text::Xslate::PP::Type::Pair;

has _items => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
);

sub BUILDARGS {
    my $self = shift;

    if(@_ == 1) {
        my($arg) = @_;
        my $items;
        if(ref($arg) eq 'ARRAY') {
            $items = $arg;
        }
        elsif(ref($arg) eq 'HASH') {
            $items = [
                map  { Text::Xslate::Type::Pair->new( key => $_, value => $arg->{$_} ) }
                sort { $a cmp $b } keys %{$arg},
            ];
        }
        else {
            $items = eval { \@{ $arg } };
            if(!defined $items) {
                $items = [];
            }
        }
        return { _items => $items };
    }
    else {
        return $self->SUPER::BUILDARGS(@_);
    }
}

sub size :method {
    my($self) = @_;
    return scalar @{$self->_items};
}

sub join :method {
    my($self, $sep) = @_;
    return join $sep, @{$self->_items};
}

sub reverse :method {
    my($self, $sep) = @_;
    return [ reverse @{$self->_items} ];
}


no Mouse;
__PACKAGE__->meta->make_immutable();
__END__

=head1 NAME

Text::Xslate::PP::Type::Array - Text::Xslate builtin array type in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
