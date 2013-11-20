package Text::Xslate::Loader::File;
use Mouse;
use Data::MessagePack;
use Digest::MD5 ();
use File::Copy ();
use File::Spec;
use File::Temp ();
use Log::Minimal;
use constant ST_MTIME => 9;

use Text::Xslate::Util ();

has assemble_cb => (
    is => 'ro',
    required => 1,
);

has cache_dir => (
    is => 'ro',
    required => 1,
);

has cache_strategy => (
    is => 'ro',
    default => 1,
);

has compiler => (
    is => 'ro',
    required => 1,
);

has include_dirs => (
    is => 'ro',
    required => 1,
);

has input_layer => (
    is => 'ro',
    required => 1,
    default => ':utf8',
);

has pre_process_handler => (
    is => 'ro',
);

has magic_template => (
    is => 'ro',
    required => 1,
);

sub build {
    my ($class, $engine) = @_;
    my $self = $class->new(
        assemble_cb     => sub { $engine->_assemble(@_) },
        # XXX Cwd::abs_path would stat() the directory, so we need to
        # to use File::Spec->rel2abs
        cache_dir       => File::Spec->rel2abs($engine->{cache_dir}),
        cache_strategy  => $engine->{cache},
        compiler        => $engine->_compiler,
        include_dirs    => $engine->{path},
        input_layer     => $engine->input_layer,
        magic_template  => $engine->magic_template,
    );
    return $self;
}

sub load {
    my ($self, $name) = @_;

    debugf("Loading %s", $name);

    # On a file system, we need to check for
    # 1) does the file exist in fs?
    # 2) if so, keep it's mtime
    # 3) check against mtime of the cache

    # XXX if the file cannot be located in the filesystem,
    # then we go kapot, so no check for defined $fi
    my $fi = $self->locate_file($name);

    # Okay, the source exists. Now consider the cache.
    #   $cache_strategy >= 2, use cache w/o checking for freshness
    #   $cache_strategy == 1, use cache if cache is fresh 
    #   $cache_strategy == 0, ignore cache

    # $cached_ent is an object with mtime and asm
    my $cached_ent;
    my $cache_strategy = $self->cache_strategy;
    debugf("Cache strategy is %d", $cache_strategy);
    if ($cache_strategy > 0) {
        # It's okay to fail
        $cached_ent = eval { $self->load_cached($fi) };
        if (my $e = $@) {
            warnf("Failed to load compiled cache from %s (%s)",
                $fi->cachepath,
                $e
            );
        }
    }

    my $asm;
    if ($cached_ent) {
        if ($cache_strategy > 1) {
            # We're careless! We just want to use the cached
            # version! Go! Go! Go!
            debugf("Freshness check disabled, and cache exists. Just use it");
            $asm = $cached_ent->asm;
            goto ASSEMBLE_AND_RETURN;
        }

        # Otherwise check for freshness 
        if ($cached_ent->is_fresher_than($fi)) {
            # Hooray, our cached version is newer than the 
            # source file! cheers! jubilations! 
            debugf("Freshness check passed, returning asm");
            $asm = $cached_ent->asm;
            goto ASSEMBLE_AND_RETURN;
        }

        # if you got here, too bad: cache is invalid.
        # it doesn't mean anything, but we say bye-bye
        # to the cached entity just to console our broken hearts
        undef $cached_ent;
    }

    # If you got here, either the cache_strategy was 0 or the cache
    # was invalid. load from source
    $asm = $self->load_file($fi);

    # store cache, if necessary
    my $cache_mtime; # XXX Should this be here?
    if ($cache_strategy > 0) {
        $cache_mtime = $self->store_cache($fi, $asm);
    }

ASSEMBLE_AND_RETURN:
    $self->assemble($asm, $name, $fi->fullpath, $fi->cachepath, $cache_mtime);
    return $asm;
}

sub assemble {
#    my ($self, $asm, $file, $fullpath, $cachepath, $mtime) = @_;
    my $self = shift;
    $self->assemble_cb->(@_);
}

# Given a list of include directories, looks for a matching file path
# Returns a FileInfo object
my $updir = File::Spec->updir;
sub locate_file {
    my ($self, $name) = @_;

    debugf("locate_file: looking for %s", $name);

    if($name =~ /\Q$updir\E/xmso) {
        die("LoadError: Forbidden component (updir: '$updir') found in file name '$name'");
    }

    my $dirs = $self->include_dirs;
    my ($fullpath, $mtime, $cache_prefix);
    foreach my $dir (@$dirs) {
        debugf("Checking in %s", $dir);
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

        # If it got here, $fullpath should exist
        return Text::Xslate::Loader::File::FileInfo->new(
            magic_template => $self->magic_template,
            name        => ref($fullpath) ? $name : $fullpath,
            fullpath    => $fullpath,
            cachepath   => File::Spec->catfile(
                $self->cache_dir,
                $cache_prefix,
                $name . 'c',
            ),
            mtime  => $mtime,
#            cache_mtime => $cache_mtime,
        );
    }

#    $engine->_error("LoadError: Cannot find '$file' (path: @{$self->{path}})");
    die "LoadError: Cannot find '$name' (include dirs: @$dirs)";
}

# Loads the compiled code from cache. Requires the full path
# to the cached file location
sub load_cached {
    my ($self, $fi) = @_;

    my $filename = $fi->cachepath;

    debugf("load_cached: %s", $filename);
    my $mtime = (stat($filename))[ST_MTIME()];
    if (! defined $mtime) {
        # stat failed. cache isn't there. sayonara
        debugf("load_cached: file %s does not exist", $filename);
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
    );
}

# Loads compile code from file. The return value is an object
# which contains "asm", and other metadata
sub load_file {
    my ($self, $fi) = @_;

    my $filename = $fi->fullpath;
    my $data;
    {
        open my $source, '<' . $self->input_layer, $filename
#        or $engine->_error("LoadError: Cannot open $fullpath for reading: $!");
            or Carp::confess("LoadError: Cannot open $filename for reading: $!");
        local $/;
        $data = <$source>;
    }

    if (my $cb = $self->pre_process_handler) {
        $data = $cb->($data);
    }

    return $self->compiler->compile($data, file => $filename);
}

sub store_cache {
    my ($self, $fi, $asm) = @_;

    my $path          = $fi->cachepath;
    debugf("Storing cache in %s", $path);
    my($volume, $dir) = File::Spec->splitpath($path);
    my $cachedir      = File::Spec->catpath($volume, $dir, '');

    if(!-e $cachedir) {
        debugf("Directory %s does not exist", $cachedir);
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

    debugf("Temporary file in %s", $temp);

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
        die $e;
    }

    if (! File::Copy::move($temp->filename, $path)) {
        Carp::carp("Xslate: Cannot rename cache file $path (ignored): $!");
    }

    debugf("Stored cache in %s", $path);
    return $newest_mtime;
}

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
        $fullpath = join ":",
            ref $fullpath,
            Digest::MD5::md5_hex(utf8::encode($fullpath))
    }
    return sprintf $self->magic_template, $fullpath;
}

package 
    Text::Xslate::Loader::File::CachedEntity;
use Mouse;
use Log::Minimal;

has asm => (is => 'rw', builder => 'build_asm', lazy => 1);
has filename => (is => 'ro', required => 1);
has magic => (is => 'ro', required => 1);
has mtime => (is => 'ro', required => 1); # Main file's mtime

sub is_fresher_than {
    my ($self, $threshold) = @_;

    debugf("CachedEntity mtime (%d), threshold (%d)",
            $self->mtime, $threshold);
    if ($self->mtime <= $threshold) {
        return;
    }

    $self->build_asm( check_freshness => $threshold );
}

sub build_asm {
    my ($self, %args) = @_;

    my $check_freshness = exists $args{check_freshness};
    my $threshold       = $args{check_freshness};

    my $filename = $self->filename;
    open my($in), '<:raw', $filename
        or die "LoadError: Cannot open $filename for reading: $!";
#        or $engine->_error("LoadError: Cannot open $filename for reading: $!");

    my $data;

    # Check against magic header.
    my $magic = $self->magic;
    read $in, $data, length($magic);
    if (! defined $data || $data ne $magic) {
#        warnf("Magic mismatch %x != %x", $data, $magic);
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
        if($check_freshness && $c->[0] eq 'depend') {
            my $dep_mtime = (stat $c->[1])[Text::Xslate::Engine::_ST_MTIME()];
            if(!defined $dep_mtime) {
                Carp::carp("Xslate: Failed to stat $c->[1] (ignored): $!");
                return undef; # purge the cache
            }
            if($dep_mtime > $threshold){
                $self->note("  _load_compiled: %s(%s) is newer than %s(%s)\n",
                    $c->[1],    scalar localtime($dep_mtime),
                    $filename, scalar localtime($threshold) )
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

    $self->asm(\@asm);
    return \@asm;
}

1;

__END__

=head1 SYNOPSIS

    package Text::Xslate;
    ...
    use Text::Xslate::Loader::File;

    has loader => (
        is => 'ro',
        lazy => 1,
        builder => 'build_loader',
    );

    sub build_loader {
        my $loader = Text::Xslate::Loader::File->new(
            cache_dir       => "/path/to/cache",
            cache_strategy  => 1,
            compiler        => $self->compiler,
            include_dirs    => [ "/path/to/dir1", "/path/to/dir2" ],
            input_layer     => $self->input_layer,
            # serial_optってのがあったけど、あとでやる
        );
    }

    sub load_file {
        my ($self, $file) = @_;
        my $asm = $loader->load($file);
    }
