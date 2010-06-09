package Text::Xslate::Bridge;
use strict;
use warnings;
use Carp ();
use Text::Xslate::Util qw(p);

my %methods;

sub bridge {
    my $class = shift;
    while(my($type, $table) = splice @_, 0, 2) {
        $methods{$class}{$type} = $table;
    }
    return;
}

sub export_into_xslate {
    my($class, $funcs_ref, @args) = @_;
    @{$funcs_ref} = $class->methods(@args);
    return;
}

sub methods {
    my($class, %args) = @_;

    if(!exists $methods{$class}) {
        croak("$class has no methods (possibly not a bride class)");
    }

    if(exists $args{-exclude}) {
        my $exclude = $args{-exclude};
        my $methods = $class->_methods;
        my @export;

        if(ref($exclude) eq 'ARRAY') {
            $exclude = { map { $_ => 1 } @{$exclude} };
        }

        if(ref($exclude) eq 'HASH') {
            @export = grep { !$exclude->{$_} } keys %{$methods};
        }
        elsif(ref($exclude) eq 'Regexp'){
            @export = grep { $_ !~ $exclude } keys %{$methods};
        }
        else {
            @export = grep { $_ ne $exclude } keys %{$methods};
        }
        return map { $_ => $methods->{$_} } @export;
    }
    else {
        return %{ $class->_methods };
    }
}

sub _methods {
    my($class) = @_;

    my $storage = $methods{$class}     ||= {};
    my $methods = $storage->{_methods} ||= {};

    foreach my $type qw(scalar hash array) {
        my $table = $storage->{$type} || next;

        while(my($name, $body) = each %{$table}) {
            $methods->{$type . '::' . $name} = $body;
        }
    }
    return $methods;
}

sub dump {
    p(\%methods);
}

1;
__END__

=head1 NAME

Text::Xslate::Bridge - The interface base class to import methods

=head1 SYNOPSIS

    package SomeTemplate::Bridge::Xslate;

    use parent qw(Text::Xslate::Bridge);

    __PACKAGE__->bride(
        scalar => \%SomeTemplate::scalar_methods,
        array  => \%SomeTemplate::array_methods,
        hash   => \%SomeTemplate::hash_methods,
    );

    # in your script

    use Text::Xslate;

    my $tx = Text::Xslate->new(
        module => [
            'SomeTemplate::Bridge::Xslate'
                => [-exclude => [qw(hash::keys hash::values)]],
        ],
    );

=head1 DESCRIPTION

This module is the base class for adaptor classes.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Bridge::TT2>

L<Text::Xslate::Bridge::Alloy>


=cut
