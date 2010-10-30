package Text::Xslate::HashWithDefault;
use strict;

use Tie::Hash;
our @ISA = qw(Tie::ExtraHash);

sub TIEHASH {
    my($class, $storage, $default) = @_;
    return bless [ $storage, $default ], $class;
}

sub FETCH {
    my($self, $key) = @_;
    my $value = $self->[0]{$key};
    if(defined $value) {
        return $value;
    }
    else {
        return ref($self->[1]) eq 'CODE'
            ? $self->[1]->($key)
            : $self->[1];
    }
}

1;
__END__

=head1 NAME

Text::Xslate::HashWithDefault - Helper class to fill in default values

=cut

