package 
    Example::Xslate::Loader::SQLiteMemcached;
use Mouse;
use Cache::Memcached;
use DBI;

extends 'Text::Xslate::Loader';

has connect_info => (
    is => 'ro',
    required => 1,
);

has db => (
    is => 'ro',
    lazy => 1,
    builder => 'build_db'
);

has memd => (
    is => 'ro',
    required => 1,
);

after configure => sub {
    my $self = shift;
    $self->memd->flush_all;
};

sub build_tempdir { }
sub build_db {
    my $self = shift;
    my $dbh = DBI->connect(@{$self->connect_info});
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
        hello_include => <<'EOM',
Hello, <: $lang :> world!
:include "footer"
EOM
        footer => "\n-- Created with Xslate",
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
        $sth->finish;
        return;
    }

    ($body, $updated_on) = $sth->fetchrow_array();
    $sth->finish;
    $asm = $self->compile($body);
    $self->memd->set($name, [$asm, $updated_on]);

ASSEMBLE:
    $self->assemble($asm, $name, $name, undef, int($updated_on));
    return $asm;
}

package main;
use strict;
use Text::Xslate;
use DBD::SQLite; # Just making it explicit, because this is an example
use File::Spec;
use File::Temp ();

my $tempdir = File::Temp->newdir();
my $cache = Cache::Memcached->new({
    servers => [ '127.0.0.1:11211' ],
    namespace => "xslate.loader.example."
});
my $xslate = Text::Xslate->new(
    loader => Example::Xslate::Loader::SQLiteMemcached->new(
        memd => $cache,
        connect_info => [
            sprintf("dbi:SQLite:dbname=%s", File::Spec->catfile($tempdir, "template.db")),
            undef, 
            undef,
            { RaiseError => 1, AutoCommit => 1}
        ],
    ),
);

foreach (1..10) {
    print $xslate->render('hello' => { lang => "Xslate" }), "\n";
    print $xslate->render('hello_include' => { lang => "Xslate" }), "\n";
}
