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

our @CARP_NOT = qw(Text::Xslate::PP::Opcode);

my %builtin_method = (
    size    => [0, TX_ENUMERABLE],
    join    => [1, TX_ENUMERABLE],
    reverse => [0, TX_ENUMERABLE],
    sort    => [0, TX_ENUMERABLE],

    keys    => [0, TX_KV],
    values  => [0, TX_KV],
    kv      => [0, TX_KV],
);

sub tx_methodcall {
    my($st, $method) = @_;

    my($invocant, @args) = @{ pop @{ $st->{ SP } } };

    if(Scalar::Util::blessed($invocant)) {
        if($invocant->can($method)) {
            my $retval = eval { $invocant->$method(@args) };
            if($@) {
                tx_error($st, "%s" . "\t...", $@);
            }
            return $retval;
        }
        # fallback to builtin methods
    }

    if(!defined $invocant) {
        tx_warn($st, "Use of nil to invoke method %s", $method);
        return undef;
    }
    elsif(my $bm = $builtin_method{$method}) {
        my($nargs, $klass) = @{$bm};
        if(@args != $nargs) {
            tx_error($st,
                "Builtin method %s requires exactly %d argument(s), "
                . "but supplied %d",
                $method, $nargs, scalar @args);
            return undef;
         }

        my $retval = eval {
            $klass->new($invocant)->$method(@args);
        };
        if($@) {
            if($@ =~ /Can't locate/) {
                last;
            }
            else {
                tx_error($st, "%s..", $@);
            }
        }
        return $retval;
    }
    tx_error($st, "Undefined method %s called for %s",
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
