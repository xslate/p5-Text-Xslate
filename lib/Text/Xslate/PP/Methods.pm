package Text::Xslate::PP::Methods;

use strict;
use warnings;
our $VERSION = 0.101201000;
package Text::Xslate::PP;

use strict;
use warnings;

our $COPIED_XS_VERSION = '0.1012';

# The below lines are copied from Text::Xslate 0.1012 by tool/copy_code_for_pp.pl.

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    literal_to_value
    import_from
);

use constant _DUMP_LOAD_FILE => scalar($DEBUG =~ /\b dump=load_file \b/xms);

use File::Spec;

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

my $XSLATE_MAGIC = qq{.xslate "%s-%s-%s"\n}; # version-syntax-escape

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    # options

    $args{suffix}       //= '.tx';
    $args{path}         //= [ '.' ];
    $args{input_layer}  //= ':utf8';
    $args{compiler}     //= 'Text::Xslate::Compiler';
    $args{syntax}       //= 'Kolon'; # passed directly to the compiler
    $args{escape}       //= 'html';
    $args{cache}        //= 1;
    $args{cache_dir}    //= File::Spec->tmpdir;

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
        require Carp;
        Carp::carp('"file" option has been deprecated. Use render($file, \%vars) instead');
    }
    if(defined $args{string}) {
        require Carp;
        Carp::carp('"string" option has been deprecated. Use render_string($string, \%vars) instead');
        $self->load_string($args{string});
    }

    return $self;
}



sub load_string { # for <input>
    my($self, $string) = @_;
    if(not defined $string) {
        $self->_error("LoadError: Template string is not given");
    }
    $self->{string} = $string;
    my $protocode = $self->_compiler->compile($string);
    $self->_initialize($protocode, undef, undef, undef, undef);
    return $protocode;
}

sub render_string {
    my($self, $string, $vars) = @_;

    local $self->{cache} = 0;
    local $self->{string};
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
        $self->_error("LoadError: Cannot find $file (path: @{$self->{path}})");
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
            or $self->_error("LoadError: Cannot open $to_read for reading: $!");

        if($is_compiled && scalar(<$in>) ne $self->_magic) {
            # magic token is not matched
            close $in;
            unlink $cachepath
                or $self->_error("LoadError: Cannot unlink $cachepath: $!");
            goto &load_file; # retry
        }

        local $/;
        $string = <$in>;
    }

    my $protocode;
    if($is_compiled) {
        $protocode = $self->_load_assembly($string);

        # checks the mtime of dependencies
        foreach my $code(@{$protocode}) {
            if($code->[0] eq 'depend') {
                my $dep_mtime = (stat $code->[1])[9];
                if($dep_mtime > ($mtime // $f->{orig_mtime})){
                    unlink $cachepath
                        or $self->_error("LoadError: Cannot unlink $cachepath: $!");
                    goto &load_file; # retry
                }
            }
        }
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
                or $self->_error("LoadError: Cannot open $cachepath for writing: $!");

            print $out $self->_magic;
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

sub _magic {
    my($self) = @_;
    return sprintf $XSLATE_MAGIC,
        $VERSION,
        $self->{syntax},
        $self->{escape},
    ;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        require Mouse::Util;
        $compiler = Mouse::Util::load_class($compiler)->new(
            engine       => $self,
            syntax      => $self->{syntax},
            escape_mode => $self->{escape},
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

sub _error {
    shift;
    unshift @_, 'Xslate: ';
    require Carp;
    goto &Carp::croak;
}


sub html_escape {
    my($s) = @_;
    return $s if ref($s) eq 'Text::Xslate::EscapedString';

    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g; # " for poor editors
    $s =~ s/'/&#39;/g;  # ' for poor editors

    return escaped_string($s);
}

sub dump :method {
    goto &Text::Xslate::Util::p;
}

1;
__END__

=pod

=head1 NAME

Text::Xslate::PP::Methods - install to copied Text::Xslate code into PP

=head1 DESCRIPTION

This module is called by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate::PP>,
L<Text::Xslate>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 by Makamaka Hannyaharamitu (makamaka).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

