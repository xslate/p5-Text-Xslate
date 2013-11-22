package 
    Example::Xslate::Loader::SQLiteMemcached;
use Mouse;
use Cache::Memcached;
use DBI;
use DBD::SQLite; # Just making it explicit, because this is an example
use File::Spec;
use File::Temp ();

has tempdir => (
    is => 'ro',
    lazy => 1,
    builder => 'build_tempdir'
);

has db => (
    is => 'ro',
    lazy => 1,
    builder => 'build_db'
);

has memd => (
    is => 'ro',
    lazy => 1,
    builder => 'build_memd'
);

has engine => (
    is => 'ro',
    required => 1,
);

has assembler => (
    is => 'ro',
    required => 1,
);

sub build {
    my ($class, $engine) = @_;

    $class->new(
        engine => $engine,
        assembler => $engine->_assembler,
    );
}

sub build_tempdir { File::Temp->newdir() }
sub build_db {
    my $self = shift;
    my $tempfile = File::Spec->catfile($self->tempdir, "templates.db");
    my $dbh = DBI->connect("dbi:SQLite:dbname=$tempfile", undef, undef, {
        RaiseError => 1,
        AutoCommit => 1,
    });

    $dbh->do(<<EOSQL);
      CREATE TABLE template (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          body TEXT NOT NULL,
          updated_on INTEGER NOT NULL,
          UNIQUE (name)
      )
EOSQL

    my %templates = (
        hello => 'Hello, <: $lang :> world!',
        hello_foo => 'Hello, <: $foo :> world!',
    );
    foreach my $name (keys %templates) {
        $dbh->do(<<EOSQL, undef, $name, $templates{$name}, time());
            INSERT INTO template (name, body, updated_on) VALUES (?, ?, ?)
EOSQL
    }
    return $dbh;
}
sub build_memd {
    my $self = shift;
    Cache::Memcached->new({
        servers => [ '127.0.0.1:11211' ],
        namespace => join(".", "templates", $self->engine->bytecode_version, ""),
    });
}

sub compile { shift->engine->compile(@_) }
sub assemble { shift->assembler->assemble(@_) }

sub load {
    my ($self, $name) = @_;

    my ($body, $asm, $updated_on);
    my $cached = $self->memd->get($name);
    if ($cached) {
        $asm = $cached->[0];
        $updated_on = $cached->[1];
        goto ASSEMBLE;
    }

    my $sth = $self->db->prepare_cached(<<EOSQL);
        SELECT body, updated_on FROM template WHERE name = ?
EOSQL
    if (! $sth->execute($name)) {
        return;
    }

    ($body, $updated_on) = $sth->fetchrow_array();
    $asm = $self->compile($body);
    $self->memd->set($name, [$asm, $updated_on]);

ASSEMBLE:
    $self->assemble($asm, $name, $name, undef, int($updated_on));
    return $asm;
}

package main;
use strict;
use Text::Xslate;

my $xslate = Text::Xslate->new();
my $loader = Example::Xslate::Loader::SQLiteMemcached->new(
    engine => $xslate,
    assembler => $xslate->_assembler,
);
$xslate->{loader} = $loader;

foreach (1..10) {
    print $xslate->render('hello' => { lang => "Xslate" }), "\n";
}
