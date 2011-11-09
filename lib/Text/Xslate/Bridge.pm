package Text::Xslate::Bridge;
use strict;
use warnings;
use Carp ();
use Text::Xslate::Util qw(p);

my %storage;

sub bridge {
    my $class = shift;
    while(my($type, $table) = splice @_, 0, 2) {
        $storage{$class}{$type} = $table;
    }
    return;
}

sub export_into_xslate {
    my($class, $funcs_ref, @args) = @_;
    push @{$funcs_ref}, $class->methods(@args);
    return;
}

sub methods {
    my($class, %args) = @_;

    if(!exists $storage{$class}) {
        Carp::croak("$class has no methods (possibly not a bride class)");
    }

    if(exists $args{-exclude}) {
        my $exclude = $args{-exclude};
        my $methods = $class->_functions;
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
        return %{ $class->_functions };
    }
}

sub _functions {
    my($class) = @_;

    my $st    = $storage{$class} ||= {};
    my $funcs = $st->{_funcs}    ||= {};

    # for methods
    foreach my $type (qw(scalar hash array)) {
        my $table = $st->{$type} || next;

        foreach my $name(keys %{$table}) {
            $funcs->{$type . '::' . $name} = $table->{$name};
        }
    }

    # for functions
    my $table = $st->{function};
    foreach my $name(keys %{$table}) {
        $funcs->{$name} = $table->{$name};
    }
    return $funcs;
}

sub dump {
    p(\%storage);
}

1;
__END__

=head1 NAME

Text::Xslate::Bridge - The interface base class to import methods

=for test_synopsis my(%nil_methods, %scalar_methods, %array_methods, %hash_methods, %functions);

=head1 SYNOPSIS

    package SomeTemplate::Bridge::Xslate;

    use parent qw(Text::Xslate::Bridge);

    __PACKAGE__->bridge(
        nil    => \%nil_methods,
        scalar => \%scalar_methods,
        array  => \%array_methods,
        hash   => \%hash_methods,

        function => \%functions,
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

=head1 INTERFACE

=head2 C<< __PACKAGE__->bridge(@mapping) :Void >>

Install a bridge module that has method I<@mapping>.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Bridge::TT2>

L<Text::Xslate::Bridge::TT2Like>

L<Text::Xslate::Bridge::Alloy>


=cut
