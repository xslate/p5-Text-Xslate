package Text::Xslate::PP::Method;
# xs/xslate-methods.xs in pure Perl
use strict;
use warnings;


use Scalar::Util ();
use Carp         ();

require Text::Xslate::PP;
require Text::Xslate::PP::State;
require Text::Xslate::PP::Type::Pair;

if(!Text::Xslate::PP::_PP_ERROR_VERBOSE()) {
    our @CARP_NOT = qw(
        Text::Xslate::PP::Opcode
    );
}

our $_st;
*_st = *Text::Xslate::PP::_current_st;

our $_context;

sub _array_first {
    my($array_ref) = @_;
    return $_st->bad_arg('first') if @_ != 1;
    return $array_ref->[0];
}

sub _array_last {
    my($array_ref) = @_;
    return $_st->bad_arg('last') if @_ != 1;
    return $array_ref->[-1];
}

sub _array_size {
    my($array_ref) = @_;
    return $_st->bad_arg('size') if @_ != 1;
    return scalar @{$array_ref};
}

sub _array_join {
    my($array_ref, $sep) = @_;
    return $_st->bad_arg('join') if @_ != 2;
    return join $sep, @{$array_ref};
}

sub _array_reverse {
    my($array_ref) = @_;
    return $_st->bad_arg('reverse') if @_ != 1;
    return [ reverse @{$array_ref} ];
}

sub _array_sort {
    my($array_ref, $callback) = @_;
    return $_st->bad_arg('sort') if !(@_ == 1 or @_ == 2);
    if(@_ == 1) {
        return [ sort @{$array_ref} ];
    }
    else {
        return [ sort {
            push @{ $_st->{ SP } }, [ $a, $b ];
            $_st->proccall($callback, $_context) + 0; # need to numify
        } @{$array_ref} ];
    }
}

sub _array_map {
    my($array_ref, $callback) = @_;
    return $_st->bad_arg('map') if @_ != 2;
    return [ map {
        push @{ $_st->{ SP } }, [ $_ ];
        $_st->proccall($callback, $_context);
    } @{$array_ref} ];
}

sub _array_reduce {
    my($array_ref, $callback) = @_;
    return $_st->bad_arg('reduce') if @_ != 2;
    return $array_ref->[0] if @{$array_ref} < 2;

    my $x = $array_ref->[0];
    for(my $i = 1; $i < @{$array_ref}; $i++) {
        push @{ $_st->{ SP } }, [ $x, $array_ref->[$i] ];
        $x = $_st->proccall($callback, $_context);
    }
    return $x;
}

sub _array_merge {
    my($array_ref, $value) = @_;
    return $_st->bad_arg('merge') if @_ != 2;
    return [ @{$array_ref}, ref($value) eq 'ARRAY' ? @{$value} : $value ];
}

sub _hash_size {
    my($hash_ref) = @_;
    return $_st->bad_arg('size') if @_ != 1;
    return scalar keys %{$hash_ref};
}

sub _hash_keys {
    my($hash_ref) = @_;
    return $_st->bad_arg('keys') if @_ != 1;
    return [sort { $a cmp $b } keys %{$hash_ref}];
}

sub _hash_values {
    my($hash_ref) = @_;
    return $_st->bad_arg('values') if @_ != 1;
    return [map { $hash_ref->{$_} } @{ _hash_keys($hash_ref) } ];
}

sub _hash_kv {
    my($hash_ref) = @_;
    $_st->bad_arg('kv') if @_ != 1;
    return [
        map { Text::Xslate::PP::Type::Pair->new(key => $_, value => $hash_ref->{$_}) }
        @{ _hash_keys($hash_ref) }
    ];
}

sub _hash_merge {
    my($hash_ref, $other_hash_ref) = @_;
    $_st->bad_arg('merge') if @_ != 2;

    return { %{$hash_ref}, %{$other_hash_ref} };
}

BEGIN {
    our %builtin_method = (
        'array::first'   => \&_array_first,
        'array::last'    => \&_array_last,
        'array::size'    => \&_array_size,
        'array::join'    => \&_array_join,
        'array::reverse' => \&_array_reverse,
        'array::sort'    => \&_array_sort,
        'array::map'     => \&_array_map,
        'array::reduce'  => \&_array_reduce,
        'array::merge'   => \&_array_merge,

        'hash::size'     => \&_hash_size,
        'hash::keys'     => \&_hash_keys,
        'hash::values'   => \&_hash_values,
        'hash::kv'       => \&_hash_kv,
        'hash::merge'    => \&_hash_merge,
    );
}

sub tx_register_builtin_methods {
    my($hv) = @_;
    our %builtin_method;
    foreach my $name(keys %builtin_method) {
        $hv->{$name} = $builtin_method{$name};
    }
}

sub tx_methodcall {
    my($st, $context, $method, $invocant, @args) = @_;

    if(Scalar::Util::blessed($invocant)) {
        my $retval = eval { $invocant->$method(@args) };
        $st->error($context, "%s", $@) if $@;
        return $retval;
    }

    my $type = ref($invocant) eq 'ARRAY' ? 'array::'
             : ref($invocant) eq 'HASH'  ? 'hash::'
             : defined($invocant)        ? 'scalar::'
             :                             'nil::';
    my $fq_name = $type . $method;

    if(my $body = $st->symbol->{$fq_name}){
        push @{ $st->{ SP } }, [ $invocant, @args ]; # re-pushmark
        local $_context = $context;
        return $st->proccall($body, $context);
    }
    if(!defined $invocant) {
        $st->warn($context, "Use of nil to invoke method %s", $method);
        return undef;
    }

    $st->error($context, "Undefined method %s called for %s",
        $method, $invocant);

    return undef;
}

1;
__END__

=head1 NAME

Text::Xslate::PP::Method - Text::Xslate builtin method call in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
