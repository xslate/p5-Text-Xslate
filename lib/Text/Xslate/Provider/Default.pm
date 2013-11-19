package Text::Xslate::Provider::Default;
use strict;
use Text::Xslate ();

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);
    return bless {%args}, $class;
}

sub build {
    my ($class, $engine) = @_;

    $class->new(
        cache => $engine->{cache},
        cache_dir => $engine->{cache_dir},
        path => $engine->{path},
    );
}

my $updir = File::Spec->updir;
sub find_file {
    my($self, $engine, $file) = @_;

    if($file =~ /\Q$updir\E/xmso) {
        $engine->_error("LoadError: Forbidden component (updir: '$updir') found in file name '$file'");
    }

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;
    foreach my $p(@{$self->{path}}) {
        $self->note("  find_file: %s in  %s ...\n", $file, $p) if Text::Xslate::Engine::_DUMP_LOAD();

        my $cache_prefix;
        if(ref $p eq 'HASH') { # virtual path
            defined(my $content = $p->{$file}) or next;
            $fullpath = \$content;

            # NOTE:
            # Because contents of virtual paths include their digest,
            # time-dependent cache verifier makes no sense.
            $orig_mtime   = 0;
            $cache_mtime  = 0;
            $cache_prefix = 'HASH';
        }
        else {
            $fullpath = File::Spec->catfile($p, $file);
            defined($orig_mtime = (stat($fullpath))[Text::Xslate::Engine::_ST_MTIME()])
                or next;
            $cache_prefix = Text::Xslate::uri_escape($p);
            if (length $cache_prefix > 127) {
                # some filesystems refuse a path part with length > 127
                $cache_prefix = $self->_digest($cache_prefix);
            }
        }

        # $file is found
        $cachepath = File::Spec->catfile(
            $self->{cache_dir},
            $cache_prefix,
            $file . 'c',
        );
        # stat() will be failed if the cache doesn't exist
        $cache_mtime = (stat($cachepath))[Text::Xslate::Engine::_ST_MTIME()];
        last;
    }

    if(not defined $orig_mtime) {
        $engine->_error("LoadError: Cannot find '$file' (path: @{$self->{path}})");
    }

    $self->note("  find_file: %s (mtime=%d)\n",
        $fullpath, $cache_mtime || 0) if Text::Xslate::Engine::_DUMP_LOAD();

    return {
        name        => ref($fullpath) ? $file : $fullpath,
        fullpath    => $fullpath,
        cachepath   => $cachepath,

        orig_mtime  => $orig_mtime,
        cache_mtime => $cache_mtime,
    };
}


sub load_file {
    my($self, $engine, $file, $mtime, $omit_augment) = @_;

    local $self->{omit_augment} = $omit_augment;

    $self->note("%s->load_file(%s)\n", $self, $file) if Text::Xslate::Engine::_DUMP_LOAD();

    if($file eq '<string>') { # simply reload it
        return $engine->load_string($self->{string_buffer});
    }

    my $fi = $self->find_file($engine, $file);

    my $asm = $self->_load_compiled($engine, $fi, $mtime) ||
        $self->_load_source($engine, $fi, $mtime);

    # $cache_mtime is undef : uses caches without any checks
    # $cache_mtime > 0      : uses caches with mtime checks
    # $cache_mtime == 0     : doesn't use caches
    my $cache_mtime;
    if($self->{cache} < 2) {
        $cache_mtime = $fi->{cache_mtime} || 0;
    }

    $engine->_assemble($asm, $file, $fi->{fullpath}, $fi->{cachepath}, $cache_mtime);
    return $asm;
}

sub slurp_template {
    my($self, $engine, $input_layer, $fullpath) = @_;

    if (ref $fullpath eq 'SCALAR') {
        return $$fullpath;
    } else {
        open my($source), '<' . $input_layer, $fullpath
            or $engine->_error("LoadError: Cannot open $fullpath for reading: $!");
        local $/;
        return scalar <$source>;
    }
}

sub _load_source {
    my($self, $engine, $fi) = @_;
    my $fullpath  = $fi->{fullpath};
    my $cachepath = $fi->{cachepath};

    $self->note("  _load_source: try %s ...\n", $fullpath) if Text::Xslate::Engine::_DUMP_LOAD();

    # This routine is called when the cache is no longer valid (or not created yet)
    # so it should be ensured that the cache, if exists, does not exist
    if(-e $cachepath) {
        unlink $cachepath
            or Carp::carp("Xslate: cannot unlink $cachepath (ignored): $!");
    }

    my $source = $self->slurp_template($engine, $engine->input_layer, $fullpath);
    $source = $self->{pre_process_handler}->($source) if $self->{pre_process_handler};
    $self->{source}{$fi->{name}} = $source if Text::Xslate::Engine::_SAVE_SRC();

    my $asm = $engine->compile($source,
        file => $fullpath,
        name => $fi->{name},
    );

    if($self->{cache} >= 1) {
        my($volume, $dir) = File::Spec->splitpath($fi->{cachepath});
        my $cachedir      = File::Spec->catpath($volume, $dir, '');
        if(not -e $cachedir) {
            require File::Path;
            eval { File::Path::mkpath($cachedir) }
                or Carp::croak("Xslate: Cannot prepare cache directory $cachepath (ignored): $@");
        }

        my $tmpfile = sprintf('%s.%d.d', $cachepath, $$, $self);

        if (open my($out), ">:raw", $tmpfile) {
            my $mtime = $self->_save_compiled($engine, $out, $asm, $fullpath, utf8::is_utf8($source));

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $tmpfile;
            }
            elsif (rename($tmpfile => $cachepath)) {
                # set the newest mtime of all the related files to cache mtime
                if (not ref $fullpath) {
                    my $main_mtime = (stat $fullpath)[Text::Xslate::Engine::_ST_MTIME()];
                    if (defined($main_mtime) && $main_mtime > $mtime) {
                        $mtime = $main_mtime;
                    }
                    utime $mtime, $mtime, $cachepath;
                    $fi->{cache_mtime} = $mtime;
                }
                else {
                    $fi->{cache_mtime} = (stat $cachepath)[Text::Xslate::Engine::_ST_MTIME()];
                }
            }
            else {
                Carp::carp("Xslate: Cannot rename cache file $cachepath (ignored): $!");
                unlink $tmpfile;
            }
        }
        else {
            Carp::carp("Xslate: Cannot open $cachepath for writing (ignored): $!");
        }
    }
    if(Text::Xslate::Engine::_DUMP_LOAD()) {
        $self->note("  _load_source: cache(mtime=%s)\n",
            defined $fi->{cache_mtime} ? $fi->{cache_mtime} : 'undef');
    }

    return $asm;
}

# load compiled templates if they are fresh enough
sub _load_compiled {
    my($self, $engine, $fi, $threshold) = @_;

    if($self->{cache} >= 2) {
        # threshold is the most latest modified time of all the related caches,
        # so if the cache level >= 2, they seems always fresh.
        $threshold = 9**9**9; # force to purge the cache
    }
    else {
        $threshold ||= $fi->{cache_mtime};
    }
    # see also tx_load_template() in xs/Text-Xslate.xs
    if(!( defined($fi->{cache_mtime}) and $self->{cache} >= 1
            and $threshold >= $fi->{orig_mtime} )) {
        $self->note( "  _load_compiled: no fresh cache: %s, %s",
            $threshold || 0, Text::Xslate::Util::p($fi) ) if Text::Xslate::Engine::_DUMP_LOAD();
        $fi->{cache_mtime} = undef;
        return undef;
    }

    my $cachepath = $fi->{cachepath};
    open my($in), '<:raw', $cachepath
        or $engine->_error("LoadError: Cannot open $cachepath for reading: $!");

    my $magic = $self->_magic_token($engine, $fi->{fullpath});
    my $data;
    read $in, $data, length($magic);
    if($data ne $magic) {
        return undef;
    }
    else {
        local $/;
        $data = <$in>;
        close $in;
    }
    my $unpacker = Data::MessagePack::Unpacker->new();
    my $offset  = $unpacker->execute($data);
    my $is_utf8 = $unpacker->data();
    $unpacker->reset();

    $unpacker->utf8($is_utf8);

    my @asm;
    if($is_utf8) { # TODO: move to XS?
        my $seed = "";
        utf8::upgrade($seed);
        push @asm, ['print_raw_s', $seed, __LINE__, __FILE__];
    }
    while($offset < length($data)) {
        $offset = $unpacker->execute($data, $offset);
        my $c = $unpacker->data();
        $unpacker->reset();

        # my($name, $arg, $line, $file, $symbol) = @{$c};
        if($c->[0] eq 'depend') {
            my $dep_mtime = (stat $c->[1])[Text::Xslate::Engine::_ST_MTIME()];
            if(!defined $dep_mtime) {
                Carp::carp("Xslate: Failed to stat $c->[1] (ignored): $!");
                return undef; # purge the cache
            }
            if($dep_mtime > $threshold){
                $self->note("  _load_compiled: %s(%s) is newer than %s(%s)\n",
                    $c->[1],    scalar localtime($dep_mtime),
                    $cachepath, scalar localtime($threshold) )
                        if Text::Xslate::Engine::_DUMP_LOAD();
                return undef; # purge the cache
            }
        }
        elsif($c->[0] eq 'literal') {
            # force upgrade to avoid UTF-8 key issues
            utf8::upgrade($c->[1]) if($is_utf8);
        }
        push @asm, $c;
    }

    if(Text::Xslate::Engine::_DUMP_LOAD()) {
        $self->note("  _load_compiled: cache(mtime=%s)\n",
            defined $fi->{cache_mtime} ? $fi->{cache_mtime} : 'undef');
    }

    return \@asm;
}

sub _save_compiled {
    my($self, $engine, $out, $asm, $fullpath, $is_utf8) = @_;
    my $mp = Data::MessagePack->new();
    local $\;
    print $out $self->_magic_token($engine, $fullpath);
    print $out $mp->pack($is_utf8 ? 1 : 0);

    my $newest_mtime = 0;
    foreach my $c(@{$asm}) {
        print $out $mp->pack($c);

        if ($c->[0] eq 'depend') {
            my $dep_mtime = (stat $c->[1])[Text::Xslate::Engine::_ST_MTIME()];
            if ($newest_mtime < $dep_mtime) {
                $newest_mtime = $dep_mtime;
            }
        }
    }
    return $newest_mtime;
}

sub _magic_token {
    my($self, $engine, $fullpath) = @_;

    $engine->{serial_opt} ||= Data::MessagePack->pack([
        $engine->_magic_token_arguments()
    ]);

    if(ref $fullpath) { # ref to content string
        $fullpath = join ':', ref($fullpath),
            $engine->_digest(${$fullpath});
    }
Carp::confess("serial_port undefined") if ! defined $engine->{serial_opt};
    return sprintf $Text::Xslate::XSLATE_MAGIC, $fullpath, $engine->{serial_opt};
}

1;
