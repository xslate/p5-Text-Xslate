package Text::Xslate::Parser;
use 5.010;
use Any::Moose;

use Text::Xslate::Symbol;
use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    is_int
    p
);

use constant _DUMP_PROTO => scalar($DEBUG =~ /\b dump=proto \b/xmsi);
use constant _DUMP_TOKEN => scalar($DEBUG =~ /\b dump=token \b/xmsi);

our @CARP_NOT = qw(Text::Xslate::Compiler Text::Xslate::Symbol);

my $ID      = qr/(?: [A-Za-z_\$][A-Za-z0-9_]* )/xms;

my $OPERATOR_TOKEN = sprintf '(?:%s)', join('|', map{ quotemeta } qw(
    ...
    ..
    == != <=> <= >=
    << >>
    += -= *= /= %= ~=
    &&= ||= //=
    ~~ =~

    && || //
    -> =>
    ::


    < >
    =
    + - * / %
    & | ^ 
    !
    .
    ~
    ? :
    ( )
    { }
    [ ]
    ;
), ',');

my %shortcut_table = (
    '=' => 'print',
);

my $CHOMP_FLAGS = qr/-/xms; # should support [-=~+] like Template-Toolkit?

my $COMMENT = qr/\# [^\n;]* (?=[;\n])?/xms;

my $CODE    = qr/ (?: (?: $STRING | [^'"] )*? ) /xms; # ' for poor editors

our $in_given;

has symbol_table => ( # the global symbol table
    is  => 'ro',
    isa => 'HashRef',

    default  => sub{ {} },

    init_arg => undef,
);

has scope => (
    is  => 'rw',
    isa => 'ArrayRef[HashRef]',

    clearer => 'init_scope',

    lazy    => 1,
    default => sub{ [ {} ] },

    init_arg => undef,
);

has token => (
    is  => 'rw',
    isa => 'Maybe[Object]',

    init_arg => undef,
);

has next_token => ( # to peep the next token
    is  => 'rw',
    isa => 'Maybe[ArrayRef]',

    init_arg => undef,
);

has input => (
    is  => 'rw',
    isa => 'Str',

    init_arg => undef,
);

has line_start => (
    is      => 'ro',
    isa     => 'Maybe[RegexpRef]',
    builder => '_build_line_start',
);
sub _build_line_start { qr/\Q:/xms }

has tag_start => (
    is      => 'ro',
    isa     => 'RegexpRef',
    builder => '_build_tag_start',
);
sub _build_tag_start { qr/\Q<:/xms }

has tag_end => (
    is      => 'ro',
    isa     => 'RegexpRef',
    builder => '_build_tag_end',
);
sub _build_tag_end { qr/\Q:>/xms }

has shortcut_table => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    builder => '_build_shortcut_table',
);
sub _build_shortcut_table { \%shortcut_table }

# attributes for error messages

has near_token => (
    is  => 'rw',

    init_arg => undef,
);

has file => (
    is  => 'rw',
    isa => 'Str',

    required => 0,
);

has line => (
    is  => 'rw',
    isa => 'Int',

    traits  => [qw(Counter)],
    handles => {
        line_inc => 'inc',
    },

    required => 0,
);

sub symbol_class() { 'Text::Xslate::Symbol' }

sub _trim {
    my($s) = @_;

    $s =~ s/\A \s+         //xms;
    $s =~ s/   [ \t]+ \n?\z//xms;

    return $s;
}

sub split {
    my ($self, $_) = @_;

    my @tokens;

    my $line_start    = $self->line_start;
    my $tag_start     = $self->tag_start;
    my $tag_end       = $self->tag_end;

    my $lex_line = defined($line_start) && qr/\A ^ [ \t]* $line_start ([^\n]* \n?) /xms;
    my $lex_tag  = qr/\A ([^\n]*?) $tag_start ($CHOMP_FLAGS?) ($CODE) ($CHOMP_FLAGS?) $tag_end /xms;
    my $lex_text = qr/\A ([^\n]* \n) /xms;

    while($_) {
        if($lex_line && s/$lex_line//xms) {
            push @tokens,
                [ code => _trim($1) ];
        }
        elsif(s/$lex_tag//xms) {
            my($text, $prechomp, $code, $postchomp) = ($1, $2, $3, $4);
            if($text){
                push @tokens, [ text => $text ];
            }
            if($prechomp) {
                push @tokens, [ 'prechomp' ];
            }
            push @tokens, [ code => _trim($code) ];

            if($postchomp) {
                push @tokens, [ 'postchomp' ];
            }
        }
        elsif(s/$lex_text//xms) {
            push @tokens, [ text => $1 ];
        }
        else {
            push @tokens, [ text => $_ ];
            last;
        }
    }

    ## tokens: @tokens
    return \@tokens;
}

sub preprocess {
    my $self = shift;

    my $tokens_ref = $self->split(@_);
    my $code = '';

    my $shortcut_table = $self->shortcut_table;
    my $shortcut       = join('|', map{ quotemeta } keys %shortcut_table);
    my $shortcut_rx    = qr/\A ($shortcut)/xms;

    for(my $i = 0; $i < @{$tokens_ref}; $i++) {
        my $token = $tokens_ref->[$i];
        given($token->[0]) {
            when('text') {
                my $s = $token->[1];

                $s =~ s/(["\\])/\\$1/gxms; # " for poor editors

                # $s may have  single new line
                my $nl = ($s =~ s/\n/\\n/xms);

                my $p = $tokens_ref->[$i-1]; # pre-token
                if(defined($p) && $p->[0] eq 'postchomp') {
                    # <: ... -:>  \nfoobar
                    #           ^^^^
                    $s =~ s/\A [ \t]* \\n//xms;
                }

                if($nl && defined($p = $tokens_ref->[$i+1])) {
                    if($p->[0] eq 'prechomp') {
                        # \n  <:- ... -:>
                        # ^^^^
                        $s =~ s/\\n [ \t]* \z//xms;
                    }
                    elsif($p->[1] =~ /\A [ \t]+ \z/xms){
                        my $nn = $tokens_ref->[$i+2];
                        if(defined($nn) && $nn->[0] eq 'prechomp') {
                            $p->[1] = '';               # chomp the next
                            $s =~ s/\\n [ \t]* \z//xms; # chomp this
                        }
                    }
                }

                $code .= qq{print_raw "$s";};
                $code .= qq{\n} if $nl;
            }
            when('code') {
                my $s = $token->[1];

                # shortcut commands
                $s =~ s/$shortcut_rx/$shortcut_table->{$1}/xms
                    if $shortcut;

                if($s =~ /\A \s* [}] \s* \z/xms){
                    $code .= $s;
                }
                elsif(chomp $s) {
                    $code .= qq{$s;\n};
                }
                else {
                    $code .= qq{$s;};
                }
            }
            when('prechomp') {
                # noop, just a marker
            }
            when('postchomp') {
                # noop, just a marker
            }
            default {
                $self->_error("Oops: Unknown token: $_");
            }
        }
    }
    print STDOUT $code, "\n" if _DUMP_PROTO;
    return $code;
}

sub lex {
    my($self) = @_;

    local *_ = \$self->{input};

    s{\G (\s) }{ $1 eq "\n" and $self->line_inc(); ""}xmsge;

    if(s/\A ($ID)//xmso){
        return [ name => $1 ];
    }
    elsif(s/\A ($OPERATOR_TOKEN)//xmso){
        return [ operator => $1 ];
    }
    elsif(s/\A $COMMENT //xmso) {
        goto &lex; # tail call
    }
    elsif(s/\A ($NUMBER)//xmso){
        return [ number => $1 ];
    }
    elsif(s/\A ($STRING)//xmso){
        return [ string => $1 ];
    }
    elsif(s/\A (\S+)//xms) {
        $self->_error("Oops: Unexpected lex symbol '$1'");
    }
    else { # empty
        return undef;
    }
}

sub parse {
    my($parser, $input, %args) = @_;

    $parser->file( $args{file} // '<input>' );
    $parser->line( $args{line} // 0 );
    $parser->near_token('(start)');
    $parser->token(undef);
    $parser->init_scope();

    local $in_given = 0;

    local $parser->{symbol_table} = { %{ $parser->symbol_table } };

    $parser->input( $parser->preprocess($input) );

    $parser->next_token( $parser->lex() );
    $parser->advance();
    my $ast = $parser->statements();

    if($parser->input ne '') {
        $parser->_error("Syntax error", $parser->token);
    }
    $parser->near_token(undef);
    $parser->next_token(undef);

    return $ast;
}

sub BUILD {
    my($parser) = @_;
    $parser->_define_basic_symbols();
    $parser->define_symbols();
    return;
}

# The grammer

sub _define_basic_symbols {
    my($parser) = @_;

    $parser->symbol('(end)')->is_block_end(1); # EOF

    $parser->symbol('(name)');

    my $s = $parser->symbol('(variable)');
    $s->arity('variable');
    $s->set_nud(\&nud_literal);

    $parser->symbol('(literal)')->set_nud(\&nud_literal);

    $parser->symbol(';');
    $parser->symbol('(');
    $parser->symbol(')');
    $parser->symbol(',');
    $parser->symbol('=>');

    # common commands
    $parser->symbol('print')    ->set_std(\&std_command);
    $parser->symbol('print_raw')->set_std(\&std_command);

    # common constants
    $parser->define_constant('nil', undef);

    return;
}

sub define_basic_operators {
    my($parser) = @_;

    $parser->prefix('{', 256, \&nud_brace);
    $parser->prefix('[', 256, \&nud_brace);

    $parser->infix('(', 256, \&led_call);
    $parser->infix('.', 256, \&led_dot);
    $parser->infix('[', 256, \&led_fetch);

    $parser->prefix('(', 200, \&nud_paren);

    $parser->prefix('!', 200)->is_logical(1);
    $parser->prefix('+', 200);
    $parser->prefix('-', 200);

    $parser->infix('*', 180);
    $parser->infix('/', 180);
    $parser->infix('%', 180);

    $parser->infix('+', 170);
    $parser->infix('-', 170);
    $parser->infix('~', 170); # connect

    $parser->infix('<',  160)->is_logical(1);
    $parser->infix('<=', 160)->is_logical(1);
    $parser->infix('>',  160)->is_logical(1);
    $parser->infix('>=', 160)->is_logical(1);

    $parser->infix('==', 150)->is_logical(1);
    $parser->infix('!=', 150)->is_logical(1);

    $parser->infix('|',  140); # filter

    $parser->infixr('&&', 130)->is_logical(1);

    $parser->infixr('||', 120)->is_logical(1);
    $parser->infixr('//', 120)->is_logical(1);
    $parser->infix('min', 120);
    $parser->infix('max', 120);

    $parser->symbol(':');
    $parser->infix('?', 110, \&led_ternary);

    $parser->assignment('=',   100);
    $parser->assignment('+=',  100);
    $parser->assignment('-=',  100);
    $parser->assignment('*=',  100);
    $parser->assignment('/=',  100);
    $parser->assignment('%=',  100);
    $parser->assignment('~=',  100);
    $parser->assignment('&&=', 100);
    $parser->assignment('||=', 100);
    $parser->assignment('//=', 100);

    $parser->prefix('not', 70)->is_logical(1);
    $parser->infix('and',  60);
    $parser->infix('or',   50);

    return;
}

sub define_symbols {
    my($parser) = @_;

    # syntax specific separators
    $parser->symbol(']');
    $parser->symbol('}')->is_block_end(1); # block end
    $parser->symbol('->');
    $parser->symbol('else');
    $parser->symbol('with');
    $parser->symbol('::');
    $parser->symbol('($_)'); # default topic variable

    # operators
    $parser->define_basic_operators();

    # statements
    $parser->symbol('{')        ->set_std(\&std_block);
    $parser->symbol('if')       ->set_std(\&std_if);
    $parser->symbol('for')      ->set_std(\&std_for);
    $parser->symbol('while' )   ->set_std(\&std_while);
    $parser->symbol('given')    ->set_std(\&std_given);
    $parser->symbol('when')     ->set_std(\&std_when);
    $parser->symbol('default')  ->set_std(\&std_when);

    $parser->symbol('include')  ->set_std(\&std_include);

    # template inheritance

    $parser->symbol('cascade')  ->set_std(\&std_cascade);
    $parser->symbol('macro')    ->set_std(\&std_proc);
    $parser->symbol('block')    ->set_std(\&std_proc);
    $parser->symbol('around')   ->set_std(\&std_proc);
    $parser->symbol('before')   ->set_std(\&std_proc);
    $parser->symbol('after')    ->set_std(\&std_proc);
    $parser->symbol('super')    ->set_std(\&std_marker);

    return;
}


sub symbol {
    my($parser, $id, $bp) = @_;

    my $s = $parser->symbol_table->{$id};
    if(defined $s) {
        if($bp && $bp >= $s->lbp) {
            $s->lbp($bp);
        }
    }
    else {
        $s = $parser->symbol_class->new(id => $id);
        $s->lbp($bp) if $bp;
        $parser->symbol_table->{$id} = $s;
    }

    return $s;
}


sub advance {
    my($parser, $id) = @_;

    my $t = $parser->token;
    if($id && $t->id ne $id) {
        $parser->_error("Expected '$id' but '$t'");
    }

    $parser->near_token($t);

    my $symtab = $parser->symbol_table;

    $t = $parser->next_token();

    if(not defined $t) {
        return $parser->token( $symtab->{"(end)"} );
    }

    $parser->next_token( $parser->lex() );

    my($arity, $value) = @{$t};
    my $proto;

    if( $arity eq "name" && $parser->next_token->[1] eq "=>" ) {
        $arity = "string";
    }

    print STDOUT "[$arity => $value]\n" if _DUMP_TOKEN;

    given($arity) {
        when("name") {
            $proto = $parser->find($value);
            $arity = $proto->arity;
        }
        when("operator") {
            $proto = $symtab->{$value};
            if(not defined $proto) {
                $parser->_error("Unknown operator '$value'");
            }
        }
        when("string") {
            $proto = $symtab->{"(literal)"};
            $arity = "literal";
        }
        when("number") {
            $proto = $symtab->{"(literal)"};
            $arity = "literal";
        }
    }

    if(not defined $proto) {
        Carp::confess("Panic: Unexpected token: $value ($arity)");
    }

    return $parser->token( $proto->clone( id => $value, arity => $arity, line => $parser->line + 1 ) );
}

sub expression {
    my($parser, $rbp) = @_;

    my $t = $parser->token;

    $parser->advance();

    my $left = $t->nud($parser);

    while($rbp < $parser->token->lbp) {
        $t = $parser->token;
        $parser->advance();
        $left = $t->led($parser, $left);
    }

    return $left;
}

sub expression_list {
    my($parser) = @_;

    my @args;
    if($parser->token->id ne ")") {
        while(1) {
            push @args, $parser->expression(0);
            my $t = $parser->token;

            if(!($t->id eq "," or $t->id eq "=>")) {
                last;
            }

            $parser->advance(); # "," or "=>"
        }
    }
    return \@args;
}

sub led_infix {
    my($parser, $symbol, $left) = @_;
    my $bin = $symbol->clone(arity => 'binary');

    $bin->first($left);
    $bin->second($parser->expression($bin->lbp));
    return $bin;
}

sub infix {
    my($parser, $id, $bp, $led) = @_;

    my $symbol = $parser->symbol($id, $bp);
    $symbol->set_led($led || \&led_infix);
    return $symbol;
}

sub led_infixr {
    my($parser, $symbol, $left) = @_;
    my $bin = $symbol->clone(arity => 'binary');
    $bin->first($left);
    $bin->second($parser->expression($bin->lbp - 1));
    return $bin;
}

sub infixr {
    my($parser, $id, $bp, $led) = @_;

    my $symbol = $parser->symbol($id, $bp);
    $symbol->set_led($led || \&led_infixr);
    return $symbol;
}

sub led_assignment {
    my($parser, $symbol, $left) = @_;

    $parser->_error("Assignment ($symbol) is forbidden", $left);
}

sub assignment {
    my($parser, $id, $bp) = @_;

    $parser->symbol($id, $bp)->set_led(\&led_assignment);
    return;
}

sub led_ternary {
    my($parser, $symbol, $left) = @_;

    my $cond = $symbol->clone(arity => 'ternary');

    $cond->first($left);
    $cond->second($parser->expression(0));
    $parser->advance(":");
    $cond->third($parser->expression(0));
    return $cond;
}

sub is_valid_field {
    my($parser, $token) = @_;
    given($token->arity) {
        when("name") {
            return 1;
        }
        when("literal") {
            return is_int($token->id);
        }
    }
    return 0;
}

sub led_dot {
    my($parser, $symbol, $left) = @_;

    my $t = $parser->token;
    if(!$parser->is_valid_field($t)) {
        $parser->_error("Expected a field name but $_ ($t)");
    }

    my $dot = $symbol->clone(arity => 'binary');

    $dot->first($left);
    $dot->second($t->clone(arity => 'literal'));

    $t = $parser->advance();

    if($t->id eq "(") {
        $parser->advance(); # "("
        $dot->third( $parser->expression_list() );
        $parser->advance(")");
        $dot->arity("methodcall");
    }

    return $dot;
}

sub led_fetch {
    my($parser, $symbol, $left) = @_;

    my $fetch = $symbol->clone(arity => 'binary');

    $fetch->first($left);
    $fetch->second($parser->expression(0));

    $parser->advance("]");
    return $fetch;
}

sub led_call {
    my($parser, $symbol, $left) = @_;

    my $call = $symbol->clone(arity => 'call');
    $call->first($left);

    $call->second( $parser->expression_list() );
    $parser->advance(")");

    return $call;
}

sub nud_prefix {
    my($parser, $symbol) = @_;
    my $un = $symbol->clone(arity => 'unary');
    $parser->reserve($un);
    $un->first($parser->expression($symbol->ubp));
    return $un;
}

sub prefix {
    my($parser, $id, $bp, $nud) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->ubp($bp);
    $symbol->set_nud($nud || \&nud_prefix);
    return $symbol;
}

sub nud_constant {
    my($parser, $symbol) = @_;

    my $c = $symbol->clone(arity => 'literal');
    $parser->reserve($c);

    return $c;
}

sub define_constant {
    my($parser, $id, $value) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->set_nud(\&nud_constant);
    $symbol->value($value);
    return;
}

sub new_scope {
    my($parser) = @_;
    push @{ $parser->scope }, {};
    return;
}

sub undefined_name {
    my($parser, $name) = @_;
    if($name =~ /\A \$/xms) {
        return $parser->symbol_table->{'(variable)'};
    }
    else {
        return $parser->symbol_table->{'(name)'};
    }
}

sub find { # find a name from all the scopes
    my($parser, $name) = @_;
    foreach my $scope(reverse @{$parser->scope}){
        my $o = $scope->{$name};
        if(defined $o) {
            return $o;
        }
    }
    return $parser->symbol_table->{$name} // $parser->undefined_name($name);
}

sub reserve { # reserve a name to the scope
    my($parser, $symbol) = @_;
    if($symbol->arity ne 'name' or $symbol->reserved) {
        return $symbol;
    }

    my $top = $parser->scope->[-1];
    my $t = $top->{$symbol->id};
    if($t) {
        if($t->reserved) {
            return $symbol;
        }
        if($t->arity eq "name") {
           $parser->_error("Already defined: $symbol");
        }
    }
    $top->{$symbol->id} = $symbol;
    $symbol->reserved(1);
    return $symbol;
}

sub define { # define a name to the scope
    my($parser, $symbol) = @_;
    my $top = $parser->scope->[-1];

    my $t = $top->{$symbol->id};
    if(defined $t) {
        $parser->_error($t->reserved ? "Already reserved: $t" : "Already defined: $t");
    }

    $top->{$symbol->id} = $symbol;

    $symbol->reserved(0);
    $symbol->set_nud(\&nud_literal);
    $symbol->remove_led();
    $symbol->remove_std();
    $symbol->lbp(0);
    #$symbol->scope($top);
    return $symbol;
}


sub nud_function{
    my($p, $s) = @_;
    my $f = $s->clone(arity => 'function');
    return $p->reserve($f);
}

sub define_function {
    my($compiler, @names) = @_;

    foreach my $name(@names) {
        my $symbol = $compiler->symbol($name);
        $symbol->set_nud(\&nud_function);
        $symbol->value($name);
    }
    return;
}

sub nud_macro{
    my($p, $s) = @_;
    my $f = $s->clone(arity => 'macro');
    return $p->reserve($f);
}

sub define_macro {
    my($compiler, @names) = @_;

    foreach my $name(@names) {
        my $symbol = $compiler->symbol($name);
        $symbol->set_nud(\&nud_macro);
        $symbol->value($name);
    }
    return;
}


sub pop_scope {
    my($parser) = @_;
    pop @{ $parser->scope };
    return;
}

sub finish_statement {
    my($parser) = @_;

    my $t = $parser->token;
    if(!($t->is_block_end or $t->id eq ";")) {
        $parser->_error("Unexpected token (the statement seems to finish): "
        . $t->id . " (" . $t->arity . ")");
    }

    return;
}

sub statement { # process one or more statements
    my($parser) = @_;
    my $t = $parser->token;
    if($t->id eq ";"){
        $parser->advance(); # ";"
        return;
    }

    if($t->has_std) { # is $t a statement?
        $parser->reserve($t);
        $parser->advance();

        # std() returns a list of nodes
        return $t->std($parser);
    }

    my $expr = $parser->expression(0);
    $parser->finish_statement();

    return $parser->symbol('print')->clone(
        arity  => 'command',
        first  => [$expr],
        line   => $expr->line,
    );
    #return $expr;
}

sub statements { # process statements
    my($parser) = @_;
    my @a;

    my $t = $parser->token;
    while(!$t->is_block_end) {
        push @a, $parser->statement();
        $t = $parser->token;
    }

    return \@a;
}

sub block {
    my($parser) = @_;
    my $t = $parser->token;
    $parser->advance("{");
    # std() returns a list of nodes
    return [$t->std($parser)];
}

sub nud_literal {
    my($parser, $symbol) = @_;
    return $symbol; # as is
}

sub nud_paren {
    my($parser, $symbol) = @_;
    my $expr = $parser->expression(0);
    $parser->advance(')');
    return $expr;
}

# for object literals
sub nud_brace {
    my($parser, $symbol) = @_;

    my $list = $parser->expression_list();

    my $end = $symbol->id eq '{' ? '}' : ']';
    $parser->advance($end);
    return $symbol->clone(
        arity => 'objectliteral',
        first => $list,
    );
}

sub std_block {
    my($parser, $symbol) = @_;
    $parser->new_scope();
    my $a = $parser->statements();
    $parser->advance('}');
    $parser->pop_scope();
    return @{$a};
}

#sub std_var {
#    my($parser, $symbol) = @_;
#    my @a;
#    while(1) {
#        my $name = $parser->token;
#        if($name->arity ne "variable") {
#            confess("Expected a new variable name, but $name is not");
#        }
#        $parser->define($name);
#        $parser->advance();
#
#        if($parser->token->id eq "=") {
#            my $t = $parser->token;
#            $parser->advance("=");
#            $t->first($name);
#            $t->second($parser->expression(0));
#            $t->arity("binary");
#            push @a, $t;
#        }
#
#        if($parser->token->id ne ",") {
#            last;
#        }
#        $parser->advance(",");
#    }
#
#    $parser->advance(";");
#    return @a;
#}

# -> VARS { STATEMENTS }
# ->      { STATEMENTS }
#         { STATEMENTS }
sub pointy {
    my($parser, $node) = @_;

    my @vars;

    $parser->new_scope();
    if($parser->token->id eq "->") {
        $parser->advance("->");
        if($parser->token->id ne "{") {
            my $paren = ($parser->token->id eq "(");

            $parser->advance("(") if $paren;

            my $t = $parser->token;
            while($t->arity eq "variable") {
                push @vars, $t;
                $parser->define($t);
                $t = $parser->advance();

                if($t->id eq ",") {
                    $t = $parser->advance(); # ","
                }
                else {
                    last;
                }
            }

            $parser->advance(")") if $paren;
        }
    }
    $node->second( \@vars );

    $parser->advance("{");
    $node->third($parser->statements());
    $parser->advance("}");
    $parser->pop_scope();

    return;
}

sub std_for {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'for');
    $proc->first( $parser->expression(0) );
    $parser->pointy($proc);
    return $proc;
}

sub std_while {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'while');
    $proc->first( $parser->expression(0) );
    $parser->pointy($proc);
    return $proc;
}

sub std_proc {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "proc");
    my $name = $parser->token;
    if($name->arity ne "name") {
        $parser->_error("Expected a name but " . $parser->token);
    }

    $parser->define_macro($name->id);
    $proc->first( $name->id );
    $parser->advance();
    $parser->pointy($proc);
    return $proc;
}

sub std_if {
    my($parser, $symbol) = @_;

    my $if = $symbol->clone(arity => "if");

    $if->first( $parser->expression(0) );
    $if->second( $parser->block() );

    my $top_if = $if;

    my $t = $parser->token;
    while($t->id eq "elsif") {
        $parser->reserve($t);
        $parser->advance(); # "elsif"

        my $elsif = $t->clone(arity => "if");
        $elsif->first(  $parser->expression(0) );
        $elsif->second( $parser->block() );
        $if->third([$elsif]);
        $if = $elsif;
        $t  = $parser->token;
    }

    if($t->id eq "else") {
        $parser->reserve($t);
        $t = $parser->advance(); # "else"

        $if->third( $t->id eq "if"
            ? $parser->statement()
            : $parser->block());
    }
    return $top_if;
}

sub std_given {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'given');
    $proc->first( $parser->expression(0) );

    local $in_given = 1;
    $parser->pointy($proc);

    if(!(defined $proc->second && @{$proc->second})) { # if no vars given
        $proc->second([
            $parser->symbol('($_)')->clone(arity => 'variable' )
        ]);
    }
    my($topic) = @{$proc->second};

    # make if-elsif-else from given-when
    my $if;
    my $elsif;
    my $else;
    foreach my $when(@{$proc->third}) {
        if($when->arity ne "when") {
            $parser->_error("Expected when blocks", $when);
        }
        $when->arity("if");

        if(defined $when->first) { # given
            if(!$when->first->is_logical) {
                my $eq = $parser->symbol('==')->clone(
                    arity  => 'binary',
                    first  => $topic,
                    second => $when->first,
                );
                $when->first($eq);
            }
        }
        else { # default
            my $true = $parser->symbol('(literal)')->clone(
                id         => 1,
                arity      => 'literal',
                is_logical => 1,
            );
            $when->first($true);
            $else = $when;
            next;
        }

        if(!defined $if) {
            $if    = $when;
            $elsif = $when;
        }
        else {
            $elsif->third([$when]);
            $elsif = $when;
        }
    }
    if(defined $else) {
        if(defined $elsif) {
            $elsif->third([$else]);
        }
        else {
            $if = $else; # only default
        }
    }
    $proc->third([$if]);
    return $proc;
}

# when/default
sub std_when {
    my($parser, $symbol) = @_;

    if(!$in_given) {
        $parser->_error("You cannot use $symbol blocks outside given blocks");
    }
    my $proc = $symbol->clone(arity => 'when');
    if($symbol->id eq "when") {
        $proc->first( $parser->expression(0) );
    }
    $proc->second( $parser->block() );
    return $proc;
}

sub std_include {
    my($parser, $symbol) = @_;

    my $arg  = $parser->expression(0);
    my $vars = $parser->localize_vars();

    $parser->finish_statement();
    return $symbol->clone(
        first  => [$arg],
        second => $vars,
        arity  => 'command',
    );
}

sub std_command {
    my($parser, $symbol) = @_;
    my $args;
    if($parser->token->id ne ";") {
        $args = $parser->expression_list();
    }

    $parser->finish_statement();
    return $symbol->clone(first => $args, arity => 'command');
}

sub _get_bare_name {
    my($parser) = @_;

    my $t = $parser->token;
    if(!($t->arity ~~ [qw(name literal)])) {
        $parser->_error("Expected name or string literal");
    }

    # "string" is ok
    if($t->arity eq 'literal') {
        $parser->advance();
        return $t->id;
    }

    # package::name
    my @parts;
    push @parts, $t->id;
    $parser->advance();

    while(1) {
        my $t = $parser->token;

        if($t->id eq "::") {
            $t = $parser->advance(); # "::"

            if($t->arity ne "name") {
                $parser->_error("Expected a name but $t");
            }

            push @parts, $t->id;
            $parser->advance();
        }
        else {
            last;
        }
    }
    return \@parts;
}

sub localize_vars {
    my($parser) = @_;
    if($parser->token->id eq "{") {
        $parser->advance();
        my $vars = $parser->expression_list();
        $parser->advance("}");
        return $vars;
    }
    return undef;
}

sub std_cascade {
    my($parser, $symbol) = @_;

    my $base;
    if($parser->token->id ne "with") {
        $base = $parser->_get_bare_name();
    }

    my $components;
    if($parser->token->id eq "with") {
        $parser->advance(); # "with"

        my @c = $parser->_get_bare_name();
        while($parser->token->id eq ",") {
            $parser->advance(); # ","
            push @c, $parser->_get_bare_name();
        }
        $components = \@c;
    }

    my $vars = $parser->localize_vars();

    $parser->finish_statement();
    return $symbol->clone(
        first  => $base,
        second => $components,
        third  => $vars,
        arity  => 'cascade');
}

# markers for the compiler
sub std_marker {
    my($parser, $symbol) = @_;
    $parser->advance(';');
    return $symbol->clone(arity => 'marker');
}

sub _error {
    my($self, $message, $near) = @_;

    $near //= $self->near_token;
    Carp::croak(sprintf 'Xslate::Parser(%s:%d): %s%s while parsing templates',
        $self->file, $self->line+1, $message,
        $near ne ';' ? ", near '$near'" : '');
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::Parser - The base class of template parsers

=head1 DESCRIPTION

This is a parser to make the abstract syntax tree from templates.

The basis of the parser is Top Down Operator Precedence.

=head1 SEE ALSO

L<http://javascript.crockford.com/tdop/tdop.html> - Top Down Operator Precedence (Douglas Crockford)

L<Text::Xslate>

=cut
