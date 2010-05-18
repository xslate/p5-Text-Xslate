package Text::Xslate::PP::Method;
# xs/xslate-methods.xs in pure Perl
use strict;
use warnings;

use Scalar::Util ();

use Text::Xslate::PP::Opcode qw(tx_error tx_warn);

use Text::Xslate::PP::Type::Pair;
use Text::Xslate::PP::Type::Array;
use Text::Xslate::PP::Type::Hash;

use constant TX_ENUMERABLE => 'Text::Xslate::PP::Type::Array';
use constant TX_KV         => 'Text::Xslate::PP::Type::Hash';

my %builtin_method = (
    size    => [0, TX_ENUMERABLE],
    join    => [1, TX_ENUMERABLE],
    reverse => [0, TX_ENUMERABLE],

    keys    => [0, TX_KV],
    values  => [0, TX_KV],
    kv      => [0, TX_KV],
);

sub tx_methodcall {
    my($st, $method) = @_;

    my($invocant, @args) = @{ pop @{ $st->{ SP } } };

    my $retval;
    if(Scalar::Util::blessed($invocant)) {
        if($invocant->can($method)) {
            $retval = eval { $invocant->$method(@args) };
            if($@) {
                tx_error($st, "%s" . "\t...", $@);
            }
            return $retval;
        }
        # fallback
    }

    if(!defined $invocant) {
        tx_warn($st, "Use of nil to invoke method %s", $method);
    }
    else {
        my $bm = $builtin_method{$method} || return undef;

        my($nargs, $klass) = @{$bm};
        if(@args != $nargs) {
            tx_error($st,
                "Builtin method %s requres exactly %d argument(s), "
                . "but supplied %d",
                $method, $nargs, scalar @args);
            return undef;
         }

         $retval = eval {
            $klass->new($invocant)->$method(@args);
        };
    }

    return $retval;
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
