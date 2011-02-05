package Text::Xslate::PP::Booster;
# to output perl code, set "XSLATE=pp=dump"
use Any::Moose;
extends qw(Text::Xslate::PP::State);

use Carp ();
use Scalar::Util ();

use Text::Xslate::PP::Const;
use Text::Xslate::Util qw(
    $DEBUG p neat
    mark_raw unmark_raw
    html_escape
    uri_escape
);

our($html_metachars, %html_escape);
BEGIN {
    *html_metachars = \$Text::Xslate::PP::html_metachars;
    *html_escape    = \%Text::Xslate::PP::html_escape;
}

require Text::Xslate::PP;
if(!Text::Xslate::PP::_PP_ERROR_VERBOSE()) {
    our @CARP_NOT = qw(
        Text::Xslate::PP
        Text::Xslate::PP::Method
    );
}

sub compile {
    my($self, $source) = @_;
    my $coderef;
    my $e = do {
        local $@;
        $coderef = eval $source;
        $@;
    };
    if(ref($coderef) ne 'CODE') {
        $e ||= "Broken source: $source";
        Carp::confess("Oops: Failed to compile PP::Booster code: $e")
    }
    return $coderef;
}

#
# functions called in booster code
#

sub call {
    my ( $st, $frame, $line, $method_call, $proc, @args ) = @_;
    my $ret;

    $st->{ pc } = $line; # update the program counter

    if ( $method_call ) { # XXX: fetch() doesn't use methodcall for speed
        my $obj = shift @args;

        unless ( defined $obj ) {
            $st->warn( [$frame, $line], "Use of nil to invoke method %s", $proc );
        }
        else {
            $ret = eval { $obj->$proc( @args ) };
            $st->error( [$frame, $line], "%s\t...", $@) if $@;
        }
    }
    else { # function call
        if(!defined $proc) {
            if ( defined $line ) {
                my $c = $st->{code}->[ $line - 1 ];
                $st->error(
                    [$frame, $line], "Undefined function is called%s",
                    $c->{ opname } eq 'fetch_s' ? " $c->{arg}()" : ""
                );
            }
        }
        elsif ( ref( $proc ) eq TXt_MACRO ) {
            $ret = $st->{ booster_macro }->{ $proc->name }->( $st, push_pad( $st->{pad}, [ @args ] ), [ $frame, $line ] )
        }
        else {
            $ret = eval { $proc->( @args ) };
            $st->error( [$frame, $line], "%s\t...", $@) if $@;
        }
    }

    return $ret;
}

sub proccall {
    my ( $st, $proc, $context ) = @_;
    my $args = pop @{$st->{SP}};
    my $ret;

    if ( ref( $proc ) eq TXt_MACRO ) {
        my @pad = ($args);
        $ret = $st->{ booster_macro }->{ $proc->name }->( $st, \@pad, $context)
    }
    else {
        $ret = eval { $proc->( @{$args} ) };
        $st->error( $context, "%s\t...", $@) if $@;
    }

    return $ret;
}



sub cond_ternary {
    my ( $value, $subref1, $subref2 ) = @_;
    $value ? $subref1->() : $subref2->();
}


sub cond_and {
    my ( $value, $subref ) = @_;
    $value ? $subref->() : $value;
}


sub cond_or {
    my ( $value, $subref ) = @_;
    !$value ? $subref->() : $value;
}


sub cond_dand {
    my ( $value, $subref ) = @_;
    defined $value ? $subref->() : $value;
}


sub cond_dor {
    my ( $value, $subref ) = @_;
    !(defined $value) ? $subref->() : $value;
}


sub push_pad {
    push @{ $_[0] }, $_[1];
    $_[0];
}


sub _macro_args_error {
    my ( $macro, $pad ) = @_;
    my $nargs = $macro->nargs;
    my $args  = scalar( @{ $pad->[ -1 ] } );
    sprintf(
        'Wrong number of arguments for %s (%d %s %d)', $macro->name, $args,  $args > $nargs ? '>' : '<', $nargs
    );
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Text::Xslate::PP::Booster - Text::Xslate code generator for pure Perl

=head1 SYNOPSIS

    # If you want to check created codes, you can use it directly.
    use Text::Xslate::PP;
    use Text::Xslate::PP::Booster;

    my $tx      = Text::Xslate->new();
    my $booster = Text::Xslate::PP::Booster->new();

    my $optext  = q{<: $value :>};
    my $code    = $booster->opcode_to_perlcode_string( $tx->compile( $optext ) );
    my $coderef = $booster->opcode_to_perlcode( $tx->compile( $optext ) );
    # $coderef takes a Text::Xslate::PP::State object

=head1 DESCRIPTION

This module is another pure Perl engine, which is much faster than
Text::Xslate::PP::Opcode, but might be less stable.

This engine is enabled by C<< $ENV{ENV}='pp=booster' >>.

=head1 APIs

=head2 new

Constructor.

    $booster = Text::Xslate::PP::Booster->new();

=head2 opcode_to_perlcode

Takes a virtual machine code created by L<Text::Xslate::Compiler>,
and returns a code reference.

  $coderef = $booster->opcode_to_perlcode( $ops );

The code reference takes C<Text::Xslate::PP::State> object in Xslate runtime processes.
Don't execute this code reference directly.

=head2 opcode_to_perlcode_string

Takes a virtual machine code created by C<Text::Xslate::Compiler>,
and returns a perl subroutine code text.

  $str = $booster->opcode_to_perlcode_string( $ops );

=head1 ABOUT BOOST CODE

C<Text::Xslate::PP::Booster> creates a code reference from a virtual machine code.

    $tx->render_string( <<'CODE', {} );
    : macro foo -> $arg {
        Hello <:= $arg :>!
    : }
    : foo($value)
    CODE

Firstly the template data is converted to opcodes:

    pushmark
    fetch_s "value"
    push
    macro "foo"
    macrocall
    print
    end
    macro_begin "foo"
    print_raw_s "    Hello "
    fetch_lvar 0
    print
    print_raw_s "!\n"
    macro_end

And the booster converted them into a perl subroutine code (you can get that
code by C<< XSLATE=dump=pp >>).

    sub {
        no warnings 'recursion';
        my ( $st ) = @_;
        my ( $sv, $pad, %macro, $depth );
        my $output = q{};
        my $vars   = $st->{ vars };

        $st->{pad} = $pad = [ [ ] ];

        # macro

        $macro{"foo"} = $st->{ booster_macro }->{"foo"} ||= sub {
            my ( $st, $pad, $f_l ) = @_;
            my $vars = $st->{ vars };
            my $mobj = $st->symbol->{ "foo" };
            my $output = q{};

            if ( @{$pad->[-1]} != $mobj->nargs ) {
                $st->error( $f_l, _macro_args_error( $mobj, $pad ) );
                return '';
            }

            if ( my $outer = $mobj->outer ) {
                my @temp = @{$pad->[-1]};
                @{$pad->[-1]}[ 0 .. $outer - 1 ] = @{$pad->[-2]}[ 0 .. $outer - 1 ];
                @{$pad->[-1]}[ $outer .. $outer + $mobj->nargs ] = @temp;
            }

            Carp::croak('Macro call is too deep (> 100) on "foo"') if ++$depth > 100;

            # print_raw_s
            $output .= "    Hello ";

            # print
            $sv = $pad->[ -1 ]->[ 0 ];
            if ( ref($sv) eq TXt_RAW ) {
                if(defined ${$sv}) {
                    $output .= $sv;
                }
                else {
                    $st->warn( ["foo", 13], "Use of nil to print" );
                }
            }
            elsif ( defined $sv ) {
                $sv =~ s/($html_metachars)/$html_escape{$1}/xmsgeo;
                $output .= $sv;
            }
            else {
                $st->warn( ["foo", 13], "Use of nil to print" );
            }

            # print_raw_s
            $output .= "!\n";

            $depth--;
            pop( @$pad );

            return mark_raw($output);
        };


        # process start

        # print
        $sv = $macro{ "foo" }->( $st, push_pad( $pad, [ $vars->{ "value" } ] ), [ "main", 5 ] );
        if ( ref($sv) eq TXt_RAW ) {
            if(defined ${$sv}) {
                $output .= $sv;
            }
            else {
                $st->warn( ["main", 6], "Use of nil to print" );
            }
        }
        elsif ( defined $sv ) {
            $sv =~ s/($html_metachars)/$html_escape{$1}/xmsgeo;
            $output .= $sv;
        }
        else {
            $st->warn( ["main", 6], "Use of nil to print" );
        }

        # process end

        return $output;
    }

So it makes the runtime speed much faster.
Of course, its initial converting process costs time and memory.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
