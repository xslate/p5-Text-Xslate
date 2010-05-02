package Text::Xslate::Parser;
use 5.010;
use Mouse;

use Text::Xslate::Symbol;
use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
);

use constant _DUMP_PROTO => ($DEBUG =~ /\b dump=proto \b/xmsi);
use constant _DUMP_TOKEN => ($DEBUG =~ /\b dump=token \b/xmsi);

our @CARP_NOT = qw(Text::Xslate::Compiler Text::Xslate::Symbol);

my $ID      = qr/(?: [A-Za-z_\$][A-Za-z0-9_]* )/xms;

my $OPERATOR = sprintf '(?:%s)', join('|', map{ quotemeta } qw(
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

has symbol_table => (
    is  => 'ro',
    isa => 'HashRef',

    default  => sub{ {} },

    init_arg => undef,
);

has scope => (
    is  => 'rw',
    isa => 'ArrayRef[HashRef]',

    default => sub{ [ {} ] },

    init_arg => undef,
);

has token => (
    is  => 'rw',
    isa => 'Object',

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

                #if($s =~ /[\{\}\[\]]\n?\z/xms){ # ???
                if($s =~ /[\}]\n?\z/xms){
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
                $self->_error("Unknown token: $_");
            }
        }
    }
    print STDOUT $code, "\n" if _DUMP_PROTO;
    return $code;
}

sub lex {
    my($self) = @_;

    local *_ = \$self->{input};

    s{\G (\s) }{ $1 eq "\n" and $self->line_inc; ""}xmsge;

    if(s/\A ($ID)//xmso){
        return [ name => $1 ];
    }
    elsif(s/\A ($STRING)//xmso){
        return [ string => $1 ];
    }
    elsif(s/\A ($OPERATOR)//xmso){
        return [ operator => $1 ];
    }
    elsif(s/\A ($NUMBER)//xmso){
        my $value = $1;
        $value =~ s/_//g;
        return [ number => $value ];
    }
    elsif(s/\A $COMMENT //xmso) {
        goto &lex; # tail call
    }
    elsif(s/\A (\S+)//xms) {
        $self->_error("Unexpected lex symbol '$1'");
    }
    else { # empty
        return undef;
    }
}

sub parse {
    my($parser, $input, %args) = @_;

    $parser->input( $parser->preprocess($input) );

    $parser->file( $args{file} // '<input>' );
    $parser->line( $args{line} // 0 );
    $parser->near_token('(start)');

    my $ast = $parser->statements();
    if($parser->input ne '') {
        $parser->near_token($parser->token);
        $parser->_error("Syntax error");
    }
    $parser->near_token(undef);
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

    $parser->symbol('(end)')->is_end(1); # EOF

    $parser->symbol('(name)');
    my $s = $parser->symbol('(variable)');
    $s->arity('variable');
    $s->set_nud(\&_nud_literal);

    $parser->symbol('(literal)')->set_nud(\&_nud_literal);

    $parser->symbol(';');

    # basic commands
    $parser->symbol('print')    ->set_std(\&_std_command);
    $parser->symbol('print_raw')->set_std(\&_std_command);

    return;
}

sub define_basic_operators {
    my($parser) = @_;

    $parser->prefix('!', 200);
    $parser->prefix('+', 200);
    $parser->prefix('-', 200);

    $parser->infix('*', 180);
    $parser->infix('/', 180);
    $parser->infix('%', 180);

    $parser->infix('+', 170);
    $parser->infix('-', 170);
    $parser->infix('~', 170); # connect

    $parser->infix('<',  160);
    $parser->infix('<=', 160);
    $parser->infix('>',  160);
    $parser->infix('>=', 160);

    $parser->infix('==', 150);
    $parser->infix('!=', 150);

    $parser->infix('|',  140); # filter

    $parser->infixr('&&', 130);

    $parser->infixr('||', 120);
    $parser->infixr('//', 120);
    $parser->infix('min', 120);
    $parser->infix('max', 120);

    $parser->symbol(':');
    $parser->infix('?', 110, \&_led_ternary);

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

    $parser->prefix('not', 70);
    $parser->infix('and',  60);
    $parser->infix('or',   50);

    return;
}

sub define_symbols {
    my($parser) = @_;

    # separators
    $parser->symbol(',');
    $parser->symbol(')');
    $parser->symbol(']');
    $parser->symbol('}')->is_end(1); # block end
    $parser->symbol('->');
    $parser->symbol('else');
    $parser->symbol('with');
    $parser->symbol('::');

    # operators
    $parser->define_basic_operators();

    $parser->infix('.', 256, \&_led_dot);
    $parser->infix('[', 256, \&_led_fetch);
    $parser->infix('(', 256, \&_led_call);

    $parser->prefix('(', 200, \&_nud_paren);

    # constants
    $parser->define_constant('nil', undef);

    # statements
    $parser->symbol('{')        ->set_std(\&_std_block);
    $parser->symbol('if')       ->set_std(\&_std_if);
    $parser->symbol('for')      ->set_std(\&_std_for);
    $parser->symbol('while' )   ->set_std(\&_std_while);

    $parser->symbol('include')  ->set_std(\&_std_command);

    # template inheritance

    $parser->symbol('cascade')  ->set_std(\&_std_bare_command);
    $parser->symbol('macro')    ->set_std(\&_std_proc);
    $parser->symbol('block')    ->set_std(\&_std_proc);
    $parser->symbol('around')   ->set_std(\&_std_proc);
    $parser->symbol('before')   ->set_std(\&_std_proc);
    $parser->symbol('after')    ->set_std(\&_std_proc);
    $parser->symbol('super')    ->set_std(\&_std_marker);

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

    $t = $parser->lex();

    if(not defined $t) {
        return $parser->token( $symtab->{"(end)"} );
    }

    print STDOUT "[@{$t}]\n" if _DUMP_TOKEN;

    my($arity, $value) = @{$t};
    my $proto;

    given($arity) {
        when("name") {
            $proto = $parser->find($value);
            $arity = $proto->arity;
        }
        when("operator") {
            $proto = $symtab->{$value};
            if(!$proto) {
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

    if(!$proto) {
        $parser->_error("Unexpected token: $value ($arity)");
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
            if($parser->token->id ne ",") {
                last;
            }
            $parser->advance(",");
        }
    }
    return \@args;
}

sub _led_infix {
    my($parser, $symbol, $left) = @_;
    my $bin = $symbol->clone(arity => 'binary');

    $bin->first($left);
    $bin->second($parser->expression($bin->lbp));
    return $bin;
}

sub infix {
    my($parser, $id, $bp, $led) = @_;

    $parser->symbol($id, $bp)->set_led($led || \&_led_infix);
    return;
}

sub _led_infixr {
    my($parser, $symbol, $left) = @_;
    my $bin = $symbol->clone(arity => 'binary');
    $bin->first($left);
    $bin->second($parser->expression($bin->lbp - 1));
    return $bin;
}

sub infixr {
    my($parser, $id, $bp, $led) = @_;

    $parser->symbol($id, $bp)->set_led($led || \&_led_infixr);
    return;
}

sub _led_assignment {
    my($parser, $symbol, $left) = @_;

    $parser->near_token($left);
    $parser->_error("Assignment ($symbol) is forbidden");
}

sub assignment {
    my($parser, $id, $bp) = @_;

    $parser->symbol($id, $bp)->set_led(\&_led_assignment);
    return;
}

sub _led_ternary {
    my($parser, $symbol, $left) = @_;

    my $cond = $symbol->clone(arity => 'ternary');

    $cond->first($left);
    $cond->second($parser->expression(0));
    $parser->advance(":");
    $cond->third($parser->expression(0));
    return $cond;
}

sub _led_dot {
    my($parser, $symbol, $left) = @_;

    my $t = $parser->token;
    if($t->arity ne "name") {
        if(!($t->arity eq "literal"
                && Mouse::Util::TypeConstraints::Int($t->id))) {
            $parser->_error("Expected a field name but $t");
        }
    }

    my $dot = $symbol->clone(arity => 'binary');

    $dot->first($left);
    $dot->second($t->clone(arity => 'literal'));

    $parser->advance();

    if($parser->token->id eq "(") {
        $parser->advance("(");
        $dot->third( $parser->expression_list() );
        $parser->advance(")");
        $dot->arity("methodcall");
    }

    return $dot;
}

sub _led_fetch {
    my($parser, $symbol, $left) = @_;

    my $fetch = $symbol->clone(arity => 'binary');

    $fetch->first($left);
    $fetch->second($parser->expression(0));

    $parser->advance("]");
    return $fetch;
}

sub _led_call {
    my($parser, $symbol, $left) = @_;

    my $call = $symbol->clone(arity => 'call');
    $call->first($left);

    $call->second( $parser->expression_list() );
    $parser->advance(")");

    return $call;
}

sub _nud_prefix {
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
    $symbol->set_nud($nud || \&_nud_prefix);
    return;
}

sub _nud_constant {
    my($parser, $symbol) = @_;

    my $c = $symbol->clone(arity => 'literal');
    $parser->reserve($c);

    return $c;
}

sub define_constant {
    my($parser, $id, $value) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->set_nud(\&_nud_constant);
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
        if($o) {
            return $o;
        }
    }
    return $parser->symbol_table->{$name} // $parser->undefined_name($name);
}

sub reserve { # reserve a name to the scope
    my($parser, $symbol) = @_;
    if($symbol->arity ne 'name' or $symbol->reserved) {
        return;
    }

    my $top = $parser->scope->[-1];
    my $t = $top->{$symbol->id};
    if($t) {
        if($t->reserved) {
            return;
        }
        if($t->arity eq "name") {
           confess("Already defined: $symbol");
        }
    }
    $top->{$symbol->id} = $symbol;
    $symbol->reserved(1);
    return;
}

sub define { # define a name to the scope
    my($parser, $symbol) = @_;
    my $top = $parser->scope->[-1];

    my $t = $top->{$symbol->id};
    if(defined $t) {
        confess($t->reserved ? "Already reserved: $t" : "Already defined: $t");
    }

    $top->{$symbol->id} = $symbol;

    $symbol->reserved(0);
    $symbol->set_nud(\&_nud_literal);
    $symbol->remove_led();
    $symbol->remove_std();
    $symbol->lbp(0);
    #$symbol->scope($top);
    return $symbol;
}


sub _nud_function{
    my($p, $s) = @_;
    my $f = $s->clone(arity => 'function');
    $p->reserve($f);
    return $f;
}

sub define_function {
    my($compiler, @names) = @_;

    foreach my $name(@names) {
        my $symbol = $compiler->symbol($name);
        $symbol->set_nud(\&_nud_function);
        $symbol->value($name);
    }
    return;
}

sub _nud_macro{
    my($p, $s) = @_;
    my $f = $s->clone(arity => 'macro');
    $p->reserve($f);
    return $f;
}

sub define_macro {
    my($compiler, @names) = @_;

    foreach my $name(@names) {
        my $symbol = $compiler->symbol($name);
        $symbol->set_nud(\&_nud_macro);
        $symbol->value($name);
    }
    return;
}


sub pop_scope {
    my($parser) = @_;
    pop @{ $parser->scope };
    return;
}

sub statement { # process one or more statements
    my($parser) = @_;
    my $t = $parser->token;

    if($t->id eq ";"){
        $parser->advance(";");
        return;
    }

    if($t->has_std) { # is $t a statement?
        $parser->advance();
        $parser->reserve($t);
        return $t->std($parser);
    }

    my $expr = $parser->expression(0);
#    if($expr->assignment && $expr->id ne "(") {
#        confess("Bad expression statement");
#    }
    $parser->advance(";");
    return $parser->symbol_class->new(
        arity  => 'command',
        id     => 'print',
        first  => [$expr],
        line   => $expr->line,
    );
    #return $expr;
}

sub statements { # process statements
    my($parser) = @_;
    my @a;

    $parser->advance();
    while(1) {
        my $t = $parser->token;
        if($t->is_end) {
            last;
        }

        push @a, $parser->statement();
    }

    return \@a;
    #return @a == 1 ? $a[0] : \@a;
}

sub block {
    my($parser) = @_;
    my $t = $parser->token;
    $parser->advance("{");
    return $t->std($parser);
}


sub _nud_literal {
    my($parser, $symbol) = @_;
    return $symbol->clone();
}

sub _nud_paren {
    my($parser, $symbol) = @_;
    my $expr = $parser->expression(0);
    $parser->advance(')');
    return $expr;
}

sub _std_block {
    my($parser, $symbol) = @_;
    $parser->new_scope();
    my $a = $parser->statements();
    $parser->advance('}');
    $parser->pop_scope();
    return $a;
}

#sub _std_var {
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
sub _pointy {
    my($parser, $node) = @_;

    $parser->advance("->");

    $parser->new_scope();
    my @vars;
    if($parser->token->id ne "{") {
        my $paren = ($parser->token->id eq "(");

        $parser->advance("(") if $paren;

        while((my $t = $parser->token)->arity eq "variable") {
            push @vars, $t;
            $parser->define($t);
            $parser->advance();

            if($parser->token->id eq ",") {
                $parser->advance(",");
            }
        }

        $parser->advance(")") if $paren;
    }
    $node->second( \@vars );

    $parser->advance("{");
    $node->third($parser->statements());
    $parser->advance("}");
    $parser->pop_scope();

    return;
}

sub _std_for {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'for');
    $proc->first( $parser->expression(0) );
    $parser->_pointy($proc);
    return $proc;
}

sub _std_while {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'while');
    $proc->first( $parser->expression(0) );
    $parser->_pointy($proc);
    return $proc;
}

sub _std_proc {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => "proc");
    my $name = $parser->token;
    if($name->arity ne "name") {
        $parser->_error("Expected a name but " . $parser->token);
    }

    $parser->define_macro($name->id);
    $proc->first( $name->id );
    $parser->advance();
    $parser->_pointy($proc);
    return $proc;
}

sub _std_if {
    my($parser, $symbol) = @_;

    my $if = $symbol->clone(arity => "if");

    $if->first( $parser->expression(0) );
    $if->second( $parser->block() );

    if($parser->token->id eq "else") {
        $parser->reserve($parser->token);
        $parser->advance("else");
        $if->third( $parser->token->id eq "if"
            ? $parser->statement()
            : $parser->block ());
    }
    return $if;
}

sub _std_command {
    my($parser, $symbol) = @_;
    my $args;
    if($parser->token->id ne ";") {
        $args = $parser->expression_list();
    }
    $parser->advance(";");
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
            $t = $parser->advance("::");

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

sub _std_bare_command {
    my($parser, $symbol) = @_;

    my $name = $parser->_get_bare_name();
    my @components;

    if($parser->token->id eq 'with') {
        $parser->advance('with');

        push @components, $parser->_get_bare_name();
        while($parser->token->id eq ',') {
            $parser->advance(',');

            push @components, $parser->_get_bare_name();
        }
    }
    $parser->advance(";");
    return $symbol->clone(
        first  => $name,
        second => \@components,
        arity  => 'bare_command');
}

# markers for the compiler
sub _std_marker {
    my($parser, $symbol) = @_;
    $parser->advance(';');
    return $symbol->clone(arity => 'marker');
}

sub _error {
    my($self, $message) = @_;

    Carp::croak(sprintf 'Xslate::Parser(%s:%d): %s%s',
        $self->file, $self->line+1, $message,
        $self->near_token ne ';' ? ", near '" . $self->near_token . "'" : '');
}

no Mouse;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::Parser - The base class of template parsers

=cut
