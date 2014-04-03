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
    if(exists $self->[0]{$key}) {
        return $self->[0]{$key};
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

=head1 SYNOPSIS

    use Text::Xslate::Util qw(hash_with_default);

    my $hash_ref = hash_with_default({ }, sub { "FILLME('@_')" });
    print $hash_ref->{foo}; # FILLME('foo')

=head1 DESCRIPTION

This is a helper class to provide C<hash_with_default()> functionality,
which is useful for debugging.

See L<Text::Xslate::Manual::Debugging> for details.

=cut

