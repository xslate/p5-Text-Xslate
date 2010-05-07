package Text::Xslate::PP;

use 5.008; # finally even other modules will run in Perl 5.008?
use strict;

our $VERSION = '0.0001';

use Carp ();
use Data::Dumper;

use Text::Xslate::PP::Const;
use Text::Xslate::PP::State;

my $TX_OPS = \%Text::Xslate::OPS;

our $XS_COMAPT_VERSION = '0.1010';

my $Depth = 0;

#
#
#

# <<< Most codes are copied and modified from Text::Xslate

use parent qw(Exporter);
our @EXPORT_OK = qw(escaped_string html_escape);

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    literal_to_value
    import_from
);

use constant _DUMP_LOAD_FILE => scalar($DEBUG =~ /\b dump=load_file \b/xms);

use File::Spec;

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

my $XSLATE_MAGIC = ".xslate $XS_COMAPT_VERSION\n";



sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    # options

    $args{suffix}       //= '.tx';
    $args{path}         //= [ '.' ];
    $args{cache_dir}    //= File::Spec->tmpdir;
    $args{input_layer}  //= ':utf8';
    $args{cache}        //= 1;
    $args{compiler}     //= 'Text::Xslate::Compiler';
    $args{syntax}       //= 'Kolon'; # passed directly to the compiler

    my %funcs;
    if(defined $args{import}) {
        %funcs = import_from(@{$args{import}});
    }
    # function => { ... } overrides imported functions
    if(my $funcs_ref = $args{function}) {
        while(my($name, $body) = each %{$funcs_ref}) {
            $funcs{$name} = $body;
        }
    }
    $args{function} = \%funcs;

    if(!ref $args{path}) {
        $args{path} = [$args{path}];
    }

    # internal data
    $args{template}       = {};

    my $self = bless \%args, $class;

    if(defined $args{file}) {
        Carp::carp('"file" option has been deprecated. Use render($file, \%vars) instead');
    }
    if(defined $args{string}) {
        Carp::carp('"string" option has been deprecated. Use render_string($string, \%vars) instead');
        $self->load_string($args{string});
    }

    return $self;
}


sub _load_input { # for <input>
    my($self) = @_;

    my $source = 0;
    my $protocode;

    if($self->{string}) {
        require Carp;
        Carp::carp('"string" option has been deprecated. Use render_string() instead');
        $source++;
        $protocode = $self->_compiler->compile($self->{string});
    }

    if($self->{protocode}) {
        $source++;
        $protocode = $self->{protocode};
    }

    if($source > 1) {
        $self->throw_error("Multiple template sources are specified");
    }

    if(defined $protocode) {
        $self->_initialize($protocode, undef, undef, undef, undef);
    }

    return $protocode;
}


sub load_string { # for <input>
    my($self, $string) = @_;
    if(not defined $string) {
        $self->throw_error("LoadError: Template string is not given");
    }
    $self->{string} = $string;
    my $protocode = $self->_compiler->compile($string);
    $self->_initialize($protocode, undef, undef, undef, undef);
    return $protocode;
}


sub render_string {
    my($self, $string, $vars) = @_;

    local $self->{cache} = 0;
    $self->load_string($string);
    return $self->render(undef, $vars);
}


sub find_file {
    my($self, $file, $mtime) = @_;

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;
    my $is_compiled;

    foreach my $p(@{$self->{path}}) {
        $fullpath = File::Spec->catfile($p, $file);
        $orig_mtime = (stat($fullpath))[9] // next; # does not exist

        $cachepath = File::Spec->catfile($self->{cache_dir}, $file . 'c');
        # find the cache
        # TODO

        if(-f $cachepath) {
            $cache_mtime = (stat(_))[9]; # compiled

            # mtime indicates the threshold time.
            # see also tx_load_template() in xs/Text-Xslate.xs
            $is_compiled = (($mtime // $cache_mtime) >= $orig_mtime);
            last;
        }
        else {
            $is_compiled = 0;
        }
    }

    if(not defined $orig_mtime) {
        $self->throw_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    return {
        fullpath    => $fullpath,
        cachepath   => $cachepath,

        orig_mtime  => $orig_mtime,
        cache_mtime => $cache_mtime,

        is_compiled => $is_compiled,
    };
}


sub load_file {
    my($self, $file, $mtime) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;
#print $file,"\n";
    if($file eq '<input>') { # simply reload it
        return $self->load_string($self->{string});
    }

    my $f = $self->find_file($file, $mtime);

    my $fullpath    = $f->{fullpath};
    my $cachepath   = $f->{cachepath};
    my $is_compiled = $f->{is_compiled};

    if($self->{cache} == 0) {
        $is_compiled = 0;
    }

    print STDOUT "---> $fullpath ($is_compiled)\n" if _DUMP_LOAD_FILE;

    my $string;
    {
        my $to_read = $is_compiled ? $cachepath : $fullpath;
        open my($in), '<' . $self->{input_layer}, $to_read
            or $self->throw_error("LoadError: Cannot open $to_read for reading: $!");

        if($is_compiled && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $cachepath
                or $self->throw_error("LoadError: Cannot unlink $cachepath: $!");
            goto &load_file; # retry
        }

        local $/;
        $string = <$in>;
    }

    my $protocode;

    if($is_compiled) {
        $protocode = $self->_load_assembly($string);
    }
    else {
        $protocode = $self->_compiler->compile($string,
            file     => $file,
            fullpath => $fullpath,
        );

        if($self->{cache}) {
            require File::Basename;

            my $cachedir = File::Basename::dirname($cachepath);
            if(not -e $cachedir) {
                require File::Path;
                File::Path::mkpath($cachedir);
            }
            open my($out), '>:raw:utf8', $cachepath
                or $self->throw_error("LoadError: Cannot open $cachepath for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $cachepath;
            }
            else {
                $is_compiled = 1;
            }
        }
    }
    # if $mtime is undef, the runtime does not check freshness of caches.
    my $cache_mtime;
    if($self->{cache} < 2) {
        if($is_compiled) {
            $cache_mtime = $f->{cache_mtime} // ( stat $cachepath )[9];
        }
        else {
            $cache_mtime = 0; # no compiled cache, always need to reload
        }
    }

    $self->_initialize($protocode, $file, $fullpath, $cachepath, $cache_mtime);
    return $protocode;
}




sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        require Mouse::Util;
        $compiler = Mouse::Util::load_class($compiler)->new(
            engine => $self,
            syntax => $self->{syntax},
        );

        if(my $funcs = $self->{function}) {
            $compiler->define_function(keys %{$funcs});
        }

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub _load_assembly {
    my($self, $assembly) = @_;

    my @protocode;
    while($assembly =~ m{
            ^[ \t]*
                ($IDENT)                        # an opname
                (?: [ \t]+ ($STRING|$NUMBER) )? # an operand
                (?:\#($NUMBER))?                # line number
                [^\n]*                          # any comments
            \n}xmsog) {

        my $name  = $1;
        my $value = $2;
        my $line  = $3;

        push @protocode, [ $name, literal_to_value($value), $line ];
    }

    return \@protocode;
}

sub throw_error {
    shift;
    unshift @_, 'Xslate: ';
    require Carp;
    goto &Carp::croak;
}

sub dump :method {
    my($self) = @_;
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self], ['xslate']);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    $dd->Useqq(1);
    return $dd->Dump();
}


sub html_escape {
    my($s) = @_;
    return $s if ref($s) eq 'Text::Xslate::EscapedString';

    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;

    return escaped_string($s);
}



# >>> Most codes are copied and modified from Text::Xslate


#
# real PP code
#

sub render {
    my ( $self, $name, $vars ) = @_;

    if ( !defined $name ) {
        $name = '<input>';
    }

    unless ( $vars and ref $vars eq 'HASH' ) {
        Carp::croak( sprintf("Xslate: Template variables must be a HASH reference, not %s", $vars ) );
    }

    my $st = tx_load_template( $self, $name );

    tx_execute( $st, undef, $vars );

    $st->{ output };
}


sub _initialize {
    my ( $self, $proto, $name, $fullpath, $cachepath, $mtime ) = @_;
    my $len = scalar( @$proto );
    my $st  = Text::Xslate::PP::State->new;

    # この処理全体的に別のところに移動させたい

    unless ( $self->{ template } ) {
    }

    unless ( defined $name ) { # $name ... filename
        $name = '<input>';
        $fullpath = $cachepath = undef;
        $mtime    = time();
    }

    if ( $self->{ function } ) {
        $st->function( $self->{ function } );
    }

    my $tmpl = []; # [ name, error_handler, mtime of the file, cachepath ,fullpath ]

    $self->{ template }->{ $name } = $tmpl;

    $tmpl->[ Text::Xslate::PP::Opcode::TXo_NAME ]      = $name;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_MTIME ]     = $mtime;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_CACHEPATH ] = $cachepath;
    $tmpl->[ Text::Xslate::PP::Opcode::TXo_FULLPATH ]  = $fullpath;

    if ( $self->{ error_handler } ) {
        $tmpl->[ Text::Xslate::PP::Opcode::TXo_ERROR_HANDLER ] = $self->{ error_handler };
    }
    else {
        $tmpl->[ Text::Xslate::PP::Opcode::TXo_ERROR_HANDLER ] = sub {
            Carp::croak( @_ );
        };
    }

    # defaultにできるものは後で直しておく
    $st->template( $tmpl );
    $st->self( $self ); # weaken!

    $st->macro( {} );

    $st->sa( undef );
    $st->sb( undef );
    $st->targ( '' );

    # stack frame
    $st->frame( [] );
    $st->current_frame( -1 );

    my $mainframe = Text::Xslate::PP::Opcode::tx_push_frame( $st ); # $st->_push_frame();

    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_NAME ]    = 'main';
    $mainframe->[ Text::Xslate::PP::Opcode::TXframe_RETADDR ] = $len;

    $st->{ output } = '';

    $st->code( [] );
    $st->code_len( $len );

    $self->{ st } = $st;

    for ( my $i = 0; $i < $len; $i++ ) {
        my $pair = $proto->[ $i ];

        unless ( $pair and ref $pair eq 'ARRAY' ) {
            Carp::croak( sprintf( "Oops: Broken code found on [%d]",  $i ) );
        }

        my ( $opname, $arg, $line ) = @$pair;
        my $opnum = $TX_OPS->{ $opname };

        unless ( $opnum ) {
            Carp::croak( sprintf( "Oops: Unknown opcode '%s' on [%d]", $opname, $i ) );
        }

        $st->code->[ $i ]->{ exec_code } = $Text::Xslate::PP::Opcode::Opcode_list->[ $opnum ];
#        $st->code->[ $i ]->{ exec_code } = $Opcodelist->[ $opnum ];
        $st->code->[ $i ]->{ opname } = $opname; # for test

        my $tx_oparg = $Text::Xslate::PP::tx_oparg->[ $opnum ];

        # 後でまとめる
        if ( $tx_oparg & TXARGf_SV ) {

#            Carp::croak( sprintf( "Oops: Opcode %s must have an argument on [%d]", $opname, $i ) )
#                unless ( defined $arg );

            if( $tx_oparg & TXARGf_KEY ) {
                $st->code->[ $i ]->{ arg } = $arg;
            }
            elsif ( $tx_oparg & TXARGf_INT ) {
                $st->code->[ $i ]->{ arg } = $arg;

                if( $tx_oparg & TXARGf_GOTO ) {
                    my $abs_addr = $i + $arg;

                    if( $abs_addr > $len ) {
                        Carp::croak(
                            sprintf( "Oops: goto address %d is out of range (must be 0 <= addr <= %d)", $arg, $len )
                        );  #これおかしくない？
                    }

                    $st->code->[ $i ]->{ arg } = $abs_addr;
                }

            }
            else {
                $st->code->[ $i ]->{ arg } = $arg;
            }

        }
        else {
            if( defined $arg ) {
                Carp::croak( sprintf( "Oops: Opcode %s has an extra argument on [%d]", $opname, $i ) );
            }
            $st->code->[ $i ]->{ arg } = undef;
        }

        # set up line number

        # special cases
        if( $opnum == $TX_OPS->{ macro_begin } ) {
            $st->macro->{ $st->code->[ $i ]->{ arg } } = $i;
        }
        elsif( $opnum == $TX_OPS->{ depend } ) {
            push @{ $tmpl }, $st->code->[ $i ]->{ arg };
        }

    }

}


sub escaped_string {
    my $str = $_[0];
    bless \$str, 'Text::Xslate::EscapedString';
}


#
# INTERNAL
#


sub tx_load_template {
    my ( $self, $name ) = @_;
    my $ttobj = $self->{ template };
    my $retried = 0;

#        Carp::croak(
#            sprintf( "Xslate: Cannot load template %s: %s", $name, "template entry is invalid" )
#        );

    RETRY:

    if( $retried > 1 ) {
        Carp::croak(
            sprintf( "Xslate: Cannot load template %s: %s", $name, "retried reloading, but failed" )
        );
    }

    unless ( $ttobj->{ $name } ) {
        tx_invoke_load_file( $self, $name );
        $retried++;
        goto RETRY;
    }

    my $tmpl = $ttobj->{ $name };

    my $cache_mtime = $tmpl->[ Text::Xslate::PP::Opcode::TXo_MTIME ];

    return $self->{ st } unless $cache_mtime;

    if( $retried > 0 ) {
        return $self->{ st };
    }
    else{
        tx_invoke_load_file( $self, $name, $cache_mtime );
        $retried++;
        goto RETRY;
    }

    Carp::croak("Xslate: Cannot load template");
}


sub tx_invoke_load_file {
    my ( $self, $name, $mtime ) = @_;
    $self->load_file( $name, $mtime );
}

sub tx_execute { no warnings 'recursion';
    my ( $st, $output, $vars ) = @_;
    my $len = $st->code_len;

    $st->{ pc }   = 0;
    $st->vars( $vars );

    if ( $Depth > 100 ) {
        Carp::croak("Execution is too deep (> 100)");
    }
    $Depth++;

    while( $st->{ pc } < $len ) {
        $st->code->[ $st->{ pc } ]->{ exec_code }->( $st );
    }

    $Depth--;
}



package Text::Xslate::PP::EscapedString;

sub new {
    my ( $class, $str ) = @_;
    bless \$str, 'Text::Xslate::EscapedString';
}

package Text::Xslate::EscapedString;

use overload (
    '""' => sub { ${ $_[0] }; },
    'eq' => sub { ${ $_[0] } eq $_[1]; },
);


1;
__END__

=head1 NAME

Text::Xslate::PP - Text::Xslate compatible pure-Perl module.

=head1 VERSION

This document describes Text::Xslate::PP version 0.001.

  Text::Xslate version 0.1010 compatible

=head1 DESCRIPTION

Text::Xslate compatible pure-Perl module.
Not yet full compatible...

=head1 SEE ALSO

L<Text::Xslate>

=head1 AUTHOR

Makamaka Hannyaharamitu E<lt>makamaka at cpan.orgE<gt>

Text::Xslate was written by Fuji, Goro (gfx).

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
