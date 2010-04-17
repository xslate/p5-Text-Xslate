package Text::Xslate;

use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.001';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms;
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms;
my $STRING  = qr/(?: $dquoted | $squoted )/xms;
my $NUMBER  = qr/(?: [+-]? [0-9]+ (?: \. [0-9]+)? )/xms;

my $XSLATE_MAGIC = ".xslate $VERSION\n";

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    $args{path}         //= [ $class->default_path ];
    $args{input_layer}  //= ':utf8';
    $args{auto_compile} //= 1;
    $args{compiler}     //= 'Text::Xslate::Compiler';

    my $self = bless \%args, $class;

    my $source = 0;
    if($args{file}) {
        $source++;
        $self->_load_file($args{file});
    }

    if($args{string}) {
        $source++;
        $self->_load_string($args{string});
    }

    if($args{assembly}) {
        $source++;
        $self->_load_assembly($args{assembly});
    }

    if($args{protocode}) {
        $source++;
        $self->_load_protocode($args{protocode});
    }

    if($source != 1) {
        my $num = ($source == 0 ? "no" : "multiple");
        $self->throw_error("$num template sources are specified");
    }

    return $self;
}

sub default_path {
    require FindBin;
    require File::Basename;
    return( File::Basename::dirname($FindBin::Bin) . "/template", $FindBin::Bin );
}

sub render;

sub _load_protocode;

sub _load_file {
    my($self, $file) = @_;

    my $fullpath;
    my $is_assembly = 0;

    foreach my $p(@{ $self->{path} }) {
        $fullpath = "$p/${file}";
        if(-f "${fullpath}c") {
            my $m1 = -M _;
            my $m2 = -M $fullpath;

            if($m1 == $m2) {
                $fullpath     .= 'c';
                $is_assembly   = 1;
            }
            last;
        }
        elsif(-f $fullpath) {
            last;
        }
        else {
            $fullpath = undef;
        }
    }

    if(not defined $fullpath) {
        $self->throw_error("Cannot find $file (path: @{$self->{path}})");
    }

    $self->{loaded} = $fullpath;

    my $string;
    {
        open my($in), '<' . $self->{input_layer}, $fullpath
            or $self->throw_error("Cannot open $fullpath for reading: $!");

        if($is_assembly && scalar(<$in>) ne $XSLATE_MAGIC) {
            # magic token is not matched
            close $in;
            unlink $fullpath or Carp::croak("Cannot unlink $fullpath: $!");
            goto &_load_file; # retry
        }
        local $/;
        $string = <$in>;
    }

    if($is_assembly) {
        $self->_load_assembly($string);
    }
    else {
        my $protocode = $self->_compiler->compile($string);

        if($self->{auto_compile}) {
            # compile templates into assemblies
            open my($out), '>:raw:utf8', "${fullpath}c"
                or $self->throw_error("Cannot open ${fullpath}c for writing: $!");

            print $out $XSLATE_MAGIC;
            print $out $self->_compiler->as_assembly($protocode);
            if(!close $out) {
                 Carp::carp("Xslate: Cannot close ${fullpath}c (ignored): $!");
                 unlink "${fullpath}c";
            }
            else {
                my $mtime = ( stat $fullpath )[9];
                utime $mtime, $mtime, "${fullpath}c";
            }
        }

        $self->_load_protocode($protocode);
    }
    return;
}

sub _compiler {
    my($self, $string) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        if(!$compiler->can('new')){
            my $f = $compiler;
            $f =~ s{::}{/}g;
            $f .= ".pm";

            my $e = do {
                local $@;
                eval { require $f };
                $@;
            };
            if($e) {
                $self->throw_error("Xslate: Cannot load the compiler: $@");
            }
        }

        $compiler = $compiler->new();
    }

    return $compiler;
}

sub _load_string {
    my($self, $string) = @_;

    my $protocode = $self->_compiler->compile($string);
    $self->_load_protocode($protocode);
    return;
}

sub _load_assembly {
    my($self, $assembly) = @_;

    # name ?arg comment
    my @protocode;
    while($assembly =~ /^\s* (\.?\w+) (?: \s+ ($STRING|$NUMBER) )? (?:\#(\d+))? [^\n]* \n/xmsg) {
        my $name  = $1;
        my $value = $2;
        my $line  = $3;

        if(defined($value)) {
            if($value =~ s/"(.+)"/$1/){
                $value =~ s/\\n/\n/g;
                $value =~ s/\\t/\t/g;
                $value =~ s/\\(.)/$1/g;
            }
            elsif($value =~ s/'(.+)'/$1/) {
                $value =~ s/\\(['\\])/$1/g; # ' for poor editors
            }
        }
        push @protocode, [ $name, $value, $line ];
    }

    #use Data::Dumper;$Data::Dumper::Indent=1;print Dumper(\@protocode);

    $self->_load_protocode(\@protocode);
    return;
}

sub throw_error {
    shift;
    unshift @_, 'Xslate: ';
    require Carp;
    goto &Carp::croak;
}

1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.001.

=head1 SYNOPSIS

    use Text::Xslate;
    use FindBin qw($Bin);

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            { title => 'River out of Eden'     },
            { title => 'Beautiful code'        },
        ],
    );

    # for files
    my $tx = Text::Xslate->new(
        # required arguments:
        file => 'foo.tx', # finds foo.txc, or foo.tx

        # optional arguments:
        path         => ["$Bin/../template"],
        auto_compile => 1,
    );

    print $tx->render(\%vars);

    # for strings
    my $template = q{
        <h1><?= $title ?></h1>
        <ul>
        ? for $books ->($book) {
            <li><?= $book.title ?></li>
        ? } # for
        </ul>
    };

    my $tx = Text::Xslate->new(
        string => $template,
    );

    print $tx->render(\%vars);

=head1 DESCRIPTION

Text::Xslate is a template engine with high performance.

This is still under development.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) -> TX >>

Creates a new xslate template code.

=head3 B<< $tx->render(\%vars) -> Str >>

Renderes a template with variables, and returns the result.

=head1 TEMPLATE SYNTAX

TODO

=head1 TODO

=over

=item *

Debuggability improvement

=item *

Template inheritance (like Text::MicroTemplate::Extended)

=item *

String filters (like Template-Toolkit)

=item *

Template inclusion

=item *

The given-when syntax

=item *

Opcode-to-XS compiler

=back

=head1 DEPENDENCIES

Perl 5.10.0 or later, and a C compiler.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<Text::MicroTemplate>

L<Text::ClearSilver>

L<Template>

L<HTML::Template>

L<HTML::Template::Pro>

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Goro Fuji (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlartistic> for details.

=cut
