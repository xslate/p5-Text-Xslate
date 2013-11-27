package Text::Xslate::Loader::File;
use Mouse;
use Data::MessagePack;
use Digest::MD5 ();
use File::Copy ();
use File::Spec;
use File::Temp ();
use Text::Xslate ();
use Text::Xslate::Util ();
use Text::Xslate::Constants qw(ST_MTIME DUMP_LOAD);

extends 'Text::Xslate::Loader';

has cache_dir => (
    is => 'rw',
);

has cache_strategy => (
    is => 'rw',
);

has include_dirs => (
    is => 'rw',
);

has input_layer => (
    is => 'rw',
    default => ':utf8',
);

has magic_template => (
    is => 'rw',
);

around extract_config_from_engine => sub {
    my ($next, $class, $engine) = @_;
    my @config = $class->$next($engine);
    return (
        @config,
        # XXX Cwd::abs_path calls stat() for the directory and raises errors if not exists,
        # so we have to use File::Spec->rel2abs instead
        cache_dir       => File::Spec->rel2abs($engine->{cache_dir}),
        cache_strategy  => $engine->{cache},
        include_dirs    => $engine->{path},
        input_layer     => $engine->input_layer,
    );
};

my $INDENT_LEVEL = 0;
sub indent_note { # for logging
    require Scope::Guard;

    $INDENT_LEVEL++;
    return Scope::Guard->new(sub {
        $INDENT_LEVEL--
    });
}
sub note {
    my $self = shift;
    my $fmt = sprintf "%s%s\n", "  " x $INDENT_LEVEL, shift;

    $self->engine->note($fmt, @_, "\n");
}

sub load_cached_asm {
    my ($self, $fi) = @_;

    # Okay, the source exists. Now consider the cache.
    #   $cache_strategy >= 2, use cache w/o checking for freshness
    #   $cache_strategy == 1, use cache if cache is fresh
    #   $cache_strategy == 0, ignore cache

    # $cached_ent is an object with mtime and asm
    my $cached_ent;
    my $cache_strategy = $self->cache_strategy;
    if (DUMP_LOAD) {
        $self->note("load: Cache strategy is %d", $cache_strategy);
    }
    if ($cache_strategy > 0) {
        # It's okay to fail
        $cached_ent = eval { $self->load_cached($fi) };
        if (my $e = $@) {
            warn(sprintf "Failed to load compiled cache from %s (%s)",
                $fi->cachepath,
                $e
            );
        }
    }

    if (! $cached_ent) {
        return;
    }

    if ($cache_strategy > 1) {
        # We're careless! We just want to use the cached
        # version! Go! Go! Go!
        if (DUMP_LOAD) {
            $self->note("Freshness check disabled, and cache exists. Just use it");
        }

        # $cache_strategy > 1 is wicked. It claims to only
        # consider the cache, and yet it still checks for
        # the cache validity.
        if (my $asm = $cached_ent->asm) {
            return $asm;
        }

        if (DUMP_LOAD) {
            $self->note("Cached template's validation failed (probably a magic mismatch)");
        }
        return;
    }

    # Otherwise check for freshness
    if ($cached_ent->is_fresher_than($fi)) {
        # Hooray, our cached version is newer than the
        # source file! cheers! jubilations!
        if (DUMP_LOAD) {
            $self->note("Freshness check passed, returning asm");
        }

        return $cached_ent->asm;
    }

    if (DUMP_LOAD) {
        $self->note("Freshness check failed.");
    }
    # if you got here, too bad: cache is invalid.
}

sub load {
    my ($self, $name) = @_;

    my $note_guard;
    if (DUMP_LOAD) {
        $self->note("load: Loading %s", $name);
        $note_guard = $self->indent_note();
    }

    # On a file system, we need to check for
    # 1) does the file exist in fs?
    # 2) if so, keep it's mtime
    # 3) check against mtime of the cache

    # XXX if the file cannot be located in the filesystem,
    # then we go kapot, so no check for defined $fi
    my $fi = $self->locate_file($name);
    if (DUMP_LOAD) {
        $self->note("load: Located file %s", $fi->fullpath);
    }

    my $cache_mtime; # XXX Should this be here?
    my $asm = $self->load_cached_asm($fi);
    if (! $asm) {
        # If you got here, either the cache_strategy was 0 or the cache
        # was invalid. load from source
        $asm = $self->load_file($fi);

        # store cache, if necessary
        if ($self->cache_strategy > 0) {
            $cache_mtime = $self->store_cache($fi, $asm);
        }
    }

    $self->assemble($asm, $name, $fi->fullpath, $fi->cachepath, $cache_mtime);
    return $asm;
}

sub assemble { shift->assembler->assemble(@_) }
sub compile  { shift->engine->compile(@_) }
sub slurp_template { shift->engine->slurp_template(@_) }

# Given a list of include directories, looks for a matching file path
# Returns a FileInfo object
my $updir = File::Spec->updir;
sub locate_file {
    my ($self, $name) = @_;

    my $note_guard;
    if (DUMP_LOAD) {
        $self->note("locate_file: looking for '%s'", $name);
        $note_guard = $self->indent_note();
    }

    if($name =~ /\Q$updir\E/xmso) {
        $self->throw_error("LoadError: Forbidden component (updir: '$updir') found in file name '$name'");
    }

    my $dirs = $self->include_dirs;
    my ($fullpath, $mtime, $cache_prefix);
    foreach my $dir (@$dirs) {
        if (DUMP_LOAD) {
            $self->note("locate_file: checking in %s", $dir);
        }
        if (ref $dir eq 'HASH') {
            # XXX need to implement virtual paths
            my $content = $dir->{$name};
            if (! defined($content)) {
                next;
            }
            $fullpath = \$content;

            # NOTE:
            # Because contents of virtual paths include their digest,
            # time-dependent cache verifier makes no sense.
            $mtime   = 0;
#            $cache_mtime  = 0;
            $cache_prefix = 'HASH';
        } else {
            $fullpath = File::Spec->catfile($dir, $name);
            $mtime    = (stat($fullpath))[ST_MTIME()];

            if (! defined $mtime) {
                next;
            }

            $cache_prefix = Text::Xslate::Util::uri_escape($dir);
            if (length $cache_prefix > 127) {
                # some filesystems refuse a path part with length > 127
                $cache_prefix = $self->_digest($cache_prefix);
            }
        }

        if (DUMP_LOAD) {
            $self->note("Found source in %s", ref($fullpath) ? $name : $fullpath);
        }

        # If it got here, $fullpath should exist
        return Text::Xslate::Loader::File::FileInfo->new(
            magic_template => $self->magic_template,
            name        => ref($fullpath) ? $name : $fullpath,
            fullpath    => $fullpath,
            cachepath   => File::Spec->catfile(
                $self->cache_dir,
                $self->engine->bytecode_version,
                $cache_prefix,
                $name . 'c',
            ),
            mtime  => $mtime,
#            cache_mtime => $cache_mtime,
        );
    }

    $self->throw_error("LoadError: Cannot find '$name' (include dirs: @$dirs)");
}

# Loads the compiled code from cache. Requires the full path
# to the cached file location
sub load_cached {
    my ($self, $fi) = @_;

    my $filename = $fi->cachepath;

    my $note_guard;
    if (DUMP_LOAD) {
        $self->note("load_cached: %s", $filename);
        $note_guard = $self->indent_note();
    }
    my $mtime = (stat($filename))[ST_MTIME()];
    if (! defined $mtime) {
        # stat failed. cache isn't there. sayonara
        if (DUMP_LOAD) {
            $self->note("load_cached: file %s does not exist", $filename);
        }
        return;
    }

    # We stop processing here, because we want to be lazy about
    # checking the validity of the included templates. In order to
    # check for the freshness, we need to check against a known
    # time, which is only provided later.
    return Text::Xslate::Loader::File::CachedEntity->new(
        mtime => $mtime,
        magic => $fi->magic,
        filename => $filename,
        loader => $self,
    );
}

# Loads compile code from file. The return value is an object
# which contains "asm", and other metadata
sub load_file {
    my ($self, $fi) = @_;

    my $filename = $fi->fullpath;

    my $note_guard;
    if (DUMP_LOAD) {
        $self->note("load_file: Loading %s", $filename);
        $note_guard = $self->indent_note();
    }
    my $data = $self->slurp_template($self->input_layer, $filename);
    if (my $cb = $self->pre_process_handler) {
        if (DUMP_LOAD) {
            $self->note("Preprocess handler called");
        }
        $data = $cb->($data);
    }

    my $asm = $self->compile($data, file => $filename);
    return $asm;
}

sub store_cache {
    my ($self, $fi, $asm) = @_;

    my $path          = $fi->cachepath;
    my $note_guard;
    if (DUMP_LOAD) {
        $self->note("store_cache: Storing cache in %s (%s)", $path, $fi->fullpath);
        $note_guard = $self->indent_note();
    }
    my($volume, $dir) = File::Spec->splitpath($path);
    my $cachedir      = File::Spec->catpath($volume, $dir, '');

    if(!-e $cachedir) {
        require File::Path;
        if (! File::Path::make_path($cachedir) || ! -d $cachedir) {
            Carp::croak("Xslate: Cannot prepare cache directory $path (ignored): $@");
        }
    }

    my $temp = File::Temp->new(
        TEMPLATE => "xslate-XXXX",
        DIR => $cachedir,
        UNLINK => 0,
    );
    binmode($temp, ':raw');

    my $newest_mtime = 0;
    eval {
        my $mp = Data::MessagePack->new();
        local $\;
        print $temp $fi->magic();
        foreach my $c(@{$asm}) {
            print $temp $mp->pack($c);

            if ($c->[0] eq 'depend') {
                my $dep_mtime = (stat $c->[1])[ST_MTIME()];
                if ($newest_mtime < $dep_mtime) {
                    $newest_mtime = $dep_mtime;
                }
            }
        }
        $temp->flush;
        $temp->close;
    };
    if (my $e = $@) {
        $temp->unlink_on_destroy(1);
        $self->throw_error("LoadError: Failed to create file cache: $e");
    }

    if (! File::Copy::move($temp->filename, $path)) {
        Carp::carp("Xslate: Cannot rename cache file $path (ignored): $!");
    }

    if (DUMP_LOAD) {
        $self->note("stored cache in %s", $path);
    }
    return $newest_mtime;
}

around log_prefix => sub { "Xslate" }; # Fool old tools

package
    Text::Xslate::Loader::File::FileInfo;
use Mouse;

has name => (is => 'ro');
has fullpath => (is => 'ro');
has cachepath => (is => 'ro');
has mtime => (is => 'ro');
has magic_template => (is => 'ro', required => 1);
has magic => (is => 'ro', lazy => 1, builder => 'build_magic');

sub build_magic {
    my $self = shift;

    my $fullpath = $self->fullpath;
    if (ref $fullpath) { # ref to content string
        utf8::encode($$fullpath);
        $fullpath = join ":",
            ref $fullpath,
            Digest::MD5::md5_hex($$fullpath);
    }
    return sprintf $self->magic_template, $fullpath;
}

package
    Text::Xslate::Loader::File::CachedEntity;
use Mouse;

has asm => (is => 'rw', builder => 'build_asm', lazy => 1);
has filename => (is => 'ro', required => 1);
has magic => (is => 'ro', required => 1);
has mtime => (is => 'ro', required => 1); # Main file's mtime
has loader => (is => 'ro', required => 1);

sub note { shift->loader->note(@_) }
sub is_fresher_than {
    my ($self, $fi) = @_;

    if ($self->mtime <= $fi->mtime) {
        if (Text::Xslate::Loader::File::DUMP_LOAD) {
            $self->note("is_fresher_than: mtime (%s) <= threshold (%s)",
                $self->mtime, $fi->mtime);
        }
        return;
    }

    my $asm = $self->build_asm( check_freshness => $fi->mtime );
    $self->asm($asm);
    return $asm;
}

sub build_asm {
    my ($self, %args) = @_;

    if (Text::Xslate::Loader::File::DUMP_LOAD) {
        $self->note("build_asm: fullpath = %s", $self->filename);
    }

    my $check_freshness = exists $args{check_freshness};
    my $threshold       = $args{check_freshness};

    my $filename = $self->filename;
    open my($in), '<:raw', $filename
        or $self->throw_error("LoadError: Cannot open $filename for reading: $!");

    my $data;

    # Check against magic header.
    my $magic = $self->magic;
    read $in, $data, length($magic);
    if (! defined $data || $data ne $magic) {
        if (Text::Xslate::Loader::File::DUMP_LOAD) {
            $self->note("build_asm: magic mismatch ('%s' != '%s')", $data, $magic);
        }
        return;
    }

    # slurp the rest of the file
    {
        local $/;
        $data = <$in>;
        close $in;
    }

    # Now we need to check for the freshness of this compiled code
    # RECURSIVELY. i.e., included templates must be checked as well
    my $unpacker = Data::MessagePack::Unpacker->new();

    # The first token is the metadata
    my $offset  = $unpacker->execute($data);
    my $meta_op = $unpacker->data();
    my $is_utf8 = $meta_op->[1]->{utf8};
    $unpacker->reset();
    $unpacker->utf8($is_utf8);

    my @asm = ($meta_op);
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

        # XXX if this is a vpath,
        if($c->[0] eq 'depend') {
            my $dep_mtime = (stat $c->[1])[Text::Xslate::Constants::ST_MTIME()];
            if(!defined $dep_mtime) {
                Carp::carp("Xslate: Failed to stat $c->[1] (ignored): $!");
                return undef; # purge the cache
            }
            if($check_freshness && $dep_mtime > $threshold){
                if (Text::Xslate::Loader::File::DUMP_LOAD) {
                    $self->note("  _load_compiled: %s(%s) is newer than %s(%s)\n",
                        $c->[1],    scalar localtime($dep_mtime),
                        $filename, scalar localtime($threshold) )
                }
                return undef; # purge the cache
            }
        }
        elsif($c->[0] eq 'literal') {
            # force upgrade to avoid UTF-8 key issues
            utf8::upgrade($c->[1]) if($is_utf8);
        }
        push @asm, $c;
    }

    return \@asm;
}

1;

__END__

=head1 SYNOPSIS

    use Text::Xslate;
    use Text::Xslate::Loader::File;

    Text::Xslate->new(
      loader => 'Text::Xslate::Loader::File',
    );

=head1 NOTES

Loaders must save data (i.e. cache) in locations that are uniquely
distinguishable by the bytecode version used. This allows you to seamlessly
upgrade between versions of Text::Xslate with differing bytecode versions

=cut
