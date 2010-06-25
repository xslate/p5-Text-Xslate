package Text::Xslate::Parser;
use Any::Moose;

use Scalar::Util ();

use Text::Xslate::Symbol;
use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    is_int any_in
    value_to_literal
    literal_to_value
    p
);

use constant _DUMP_PROTO => scalar($DEBUG =~ /\b dump=proto \b/xmsi);
use constant _DUMP_TOKEN => scalar($DEBUG =~ /\b dump=token \b/xmsi);

our @CARP_NOT = qw(Text::Xslate::Compiler Text::Xslate::Symbol);

my $ID      = qr/(?: (?:[A-Za-z_]|\$\~?) [A-Za-z0-9_]* )/xms;

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
    ++ --

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

has [qw(compiler engine)] => (
    is       => 'rw',
    required => 0,
    weak_ref => 1,
);

has symbol_table => ( # the global symbol table
    is  => 'ro',
    isa => 'HashRef',

    default  => sub{ {} },

    init_arg => undef,
);

has iterator_element => (
    is  => 'rw',
    isa => 'HashRef',

    lazy     => 1,
    default  => sub { {} },

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

has next_token => ( # to peek the next token
    is  => 'rw',
    isa => 'Maybe[ArrayRef]',

    init_arg => undef,
);

has [qw(following_newline statement_is_finished)] => (
    is  => 'rw',
    isa => 'Bool',

    init_arg => undef,
);

has input => (
    is  => 'rw',
    isa => 'Str',

    init_arg => undef,
);

has line_start => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    coerce  => 1,
    builder => '_build_line_start',
);
sub _build_line_start { ':' }

has tag_start => (
    is      => 'ro',
    isa     => 'Str',
    coerce  => 1,
    builder => '_build_tag_start',
);
sub _build_tag_start { '<:' }

has tag_end => (
    is      => 'ro',
    isa     => 'Str',
    coerce  => 1,
    builder => '_build_tag_end',
);
sub _build_tag_end { ':>' }

has shortcut_table => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    builder => '_build_shortcut_table',
);
sub _build_shortcut_table { \%shortcut_table }

has in_given => (
    is       => 'rw',
    isa      => 'Bool',
    init_arg => undef,
);

# attributes for error messages

has near_token => (
    is  => 'rw',

    init_arg => undef,
);

has file => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has line => (
    is       => 'rw',
    isa      => 'Int',
    required => 0,
);

sub symbol_class() { 'Text::Xslate::Symbol' }

sub trim_code {
    my($parser, $s) = @_;

    $s =~ s/\A \s+         //xms;
    $s =~ s/   [ \t]+ \n?\z//xms;

    return $s;
}

# split templates by tags before tokanizing
sub split :method {
    my $parser  = shift;
    local($_) = @_;

    my @tokens;

    my $line_start    = $parser->line_start;
    my $tag_start     = $parser->tag_start;
    my $tag_end       = $parser->tag_end;

    my $lex_line_code = defined($line_start) && qr/\A ^ [ \t]* \Q$line_start\E ([^\n]* \n?) /xms;
    my $lex_tag_start = qr/\A \Q$tag_start\E ($CHOMP_FLAGS?)/xms;
    my $lex_tag_end   = qr/\A ($CODE) ($CHOMP_FLAGS?) \Q$tag_end\E/xms;

    my $lex_text = qr/\A ( [^\n]*? (?: \n | (?= \Q$tag_start\E ) | \z ) ) /xms;

    my $in_tag = 0;

    while($_) {
        if($in_tag) {
            if(s/$lex_tag_end//xms) {
                $in_tag = 0;

                my($code, $chomp) = ($1, $2);

                push @tokens, [ code => $code ];
                if($chomp) {
                    push @tokens, [ postchomp => $chomp ];
                }
            }
            else {
                $parser->near_token((split /\n/, $_)[0]);
                $parser->_error("Malformed templates");
            }
        }
        # not $in_tag
        elsif($lex_line_code && s/$lex_line_code//xms) {
            push @tokens, [ code => $1 ];
        }
        elsif(s/$lex_tag_start//xms) {
            $in_tag = 1;

            my $chomp = $1;
            if($chomp) {
                push @tokens, [ prechomp => $chomp ];
            }
        }
        elsif(s/$lex_text//xms) {
            push @tokens, [ text => $1 ] if length($1);
        }
        else {
            confess "Oops: Unreached code, near" . p($_);
        }
    }
    #p(\@tokens);
    return \@tokens;
}

sub preprocess {
    my($parser, $input) = @_;

    # tokenization

    my $tokens_ref = $parser->split($input);
    my $code = '';

    my $shortcut_table = $parser->shortcut_table;
    my $shortcut       = join('|', map{ quotemeta } keys %shortcut_table);
    my $shortcut_rx    = qr/\A ($shortcut)/xms;

    for(my $i = 0; $i < @{$tokens_ref}; $i++) {
        my($type, $s) = @{ $tokens_ref->[$i] };

        if($type eq 'text') {
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
        elsif($type eq 'code') {
            # shortcut commands
            $s =~ s/$shortcut_rx/$shortcut_table->{$1}/xms
                if $shortcut;

            $s = $parser->trim_code($s);

            if($s =~ /\A \s* [}] \s* \z/xms){
                $code .= $s;
            }
            elsif(chomp $s) {
                $code .= qq{$s\n};
            }
            else {
                $code .= qq{$s;}; # auto semicolon insertion
            }
        }
        elsif($type eq 'prechomp') {
            # noop, just a marker
        }
        elsif($type eq 'postchomp') {
            # noop, just a marker
        }
        else {
            $parser->_error("Oops: Unknown token: $s ($type)");
        }
    }
    print STDOUT $code, "\n" if _DUMP_PROTO;
    return $code;
}

sub parse {
    my($parser, $input, %args) = @_;

    $parser->file( $args{file} || '<input>' );
    $parser->line( $args{line} || 1 );
    $parser->init_scope();
    $parser->in_given(0);

    local $parser->{symbol_table} = { %{ $parser->symbol_table } };
    local $parser->{near_token};
    local $parser->{next_token};
    local $parser->{token};

    $parser->input( $parser->preprocess($input) );

    $parser->next_token( $parser->look_ahead() );
    $parser->advance();
    my $ast = $parser->statements();

    if($parser->input ne '') {
        $parser->_error("Syntax error", $parser->token, $parser->input);
    }

    return $ast;
}

sub BUILD {
    my($parser) = @_;
    $parser->_init_basic_symbols();
    $parser->init_symbols();
    $parser->init_iterator_elements();
    return;
}

# The grammer

sub _init_basic_symbols {
    my($parser) = @_;

    $parser->symbol('(end)')->is_block_end(1); # EOF

    # prototypes of value symbols
    my $s;
    $s = $parser->symbol('(name)');
    $s->arity('name');
    $s->is_value(1);

    $s = $parser->symbol('(variable)');
    $s->arity('variable');
    $s->is_value(1);

    $s = $parser->symbol('(literal)');
    $s->arity('literal');
    $s->is_value(1);

    # common separators
    $parser->symbol(';');
    $parser->symbol('(');
    $parser->symbol(')');
    $parser->symbol('{');
    $parser->symbol('}');
    $parser->symbol('[');
    $parser->symbol(']');
    $parser->symbol(',')  ->is_comma(1);
    $parser->symbol('=>') ->is_comma(1);

    # common commands
    $parser->symbol('print')    ->set_std(\&std_command);
    $parser->symbol('print_raw')->set_std(\&std_command);

    # common literals
    $parser->define_literal(nil   => undef);
    $parser->define_literal(true  => 1);
    $parser->define_literal(false => 0);

    return;
}

sub init_basic_operators {
    my($parser) = @_;

    # define operator precedence

    $parser->prefix('{', 256, \&nud_brace);
    $parser->prefix('[', 256, \&nud_brace);

    $parser->infix('(', 256, \&led_call);
    $parser->infix('.', 256, \&led_dot);
    $parser->infix('[', 256, \&led_fetch);

    $parser->prefix('(', 256, \&nud_paren);

    $parser->prefix('!', 200)->is_logical(1);
    $parser->prefix('+', 200);
    $parser->prefix('-', 200);

    $parser->infix('*', 190);
    $parser->infix('/', 190);
    $parser->infix('%', 190);

    $parser->infix('+', 180);
    $parser->infix('-', 180);
    $parser->infix('~', 180); # connect

    $parser->prefix('defined', 170, \&nud_defined); # named unary operator

    $parser->infix('<',  160)->is_logical(1);
    $parser->infix('<=', 160)->is_logical(1);
    $parser->infix('>',  160)->is_logical(1);
    $parser->infix('>=', 160)->is_logical(1);

    $parser->infix('==',  150)->is_logical(1);
    $parser->infix('!=',  150)->is_logical(1);
    $parser->infix('<=>', 150);
    $parser->infix('cmp', 150);
    $parser->infix('~~',  150);

    $parser->infix('|',  140, \&led_bar);

    $parser->infix('&&', 130)->is_logical(1);

    $parser->infix('||', 120)->is_logical(1);
    $parser->infix('//', 120)->is_logical(1);
    $parser->infix('min', 120);
    $parser->infix('max', 120);

    $parser->symbol(':');
    $parser->infixr('?', 110, \&led_ternary);

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
    $parser->infix('and',  60)->is_logical(1);
    $parser->infix('or',   50)->is_logical(1);

    return;
}

sub init_symbols {
    my($parser) = @_;

    # syntax specific separators
    $parser->symbol('{');
    $parser->symbol('}')->is_block_end(1); # block end
    $parser->symbol('->');
    $parser->symbol('else');
    $parser->symbol('with');
    $parser->symbol('::');

    # operators
    $parser->init_basic_operators();

    # statements
    $parser->symbol('if')       ->set_std(\&std_if);
    $parser->symbol('for')      ->set_std(\&std_for);
    $parser->symbol('while' )   ->set_std(\&std_while);
    $parser->symbol('given')    ->set_std(\&std_given);
    $parser->symbol('when')     ->set_std(\&std_when);
    $parser->symbol('default')  ->set_std(\&std_when);

    $parser->symbol('include')  ->set_std(\&std_include);

    # macros

    $parser->symbol('cascade')  ->set_std(\&std_cascade);
    $parser->symbol('macro')    ->set_std(\&std_proc);
    $parser->symbol('around')   ->set_std(\&std_proc);
    $parser->symbol('before')   ->set_std(\&std_proc);
    $parser->symbol('after')    ->set_std(\&std_proc);
    $parser->symbol('block')    ->set_std(\&std_macro_block);
    $parser->symbol('super')    ->set_std(\&std_marker);
    $parser->symbol('override') ->set_std(\&std_override);

    $parser->symbol('->')       ->set_nud(\&nud_lambda);

    # lexical variables/constants stuff
    $parser->symbol('constant')->set_nud(\&nud_constant);
    $parser->symbol('my'      )->set_nud(\&nud_constant);

    return;
}

sub init_iterator_elements {
    my($parser) = @_;

    $parser->iterator_element({
        index     => \&iterator_index,
        count     => \&iterator_count,
        is_first  => \&iterator_is_first,
        is_last   => \&iterator_is_last,
        body      => \&iterator_body,
        size      => \&iterator_size,
        max_index => \&iterator_max_index,
        peek_next => \&iterator_peek_next,
        peek_prev => \&iterator_peek_prev,
        cycle     => \&iterator_cycle,
    });

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

sub look_ahead {
    my($parser) = @_;

    local *_ = \$parser->{input};

    my $i = 0;
    s{\G (\s) }{ $1 eq "\n" and ++$i; "" }xmsge;
    if($i) {
        $parser->following_newline(1);
        $parser->line( $parser->line + $i );
    }
    else {
        $parser->following_newline(0);
    }

    if(s/\A ($ID)//xmso){
        return [ name => $1 ];
    }
    elsif(s/\A ($OPERATOR_TOKEN)//xmso){
        return [ operator => $1 ];
    }
    elsif(s/\A $COMMENT //xmso) {
        goto &look_ahead; # tail recursion
    }
    elsif(s/\A ($NUMBER)//xmso){
        return [ number => $1 ];
    }
    elsif(s/\A ($STRING)//xmso){
        return [ string => $1 ];
    }
    elsif(s/\A (\S+)//xms) {
        $parser->_error("Oops: Unexpected lex symbol '$1'");
    }
    else { # empty
        return [ special => '(end)' ];
    }
}

sub advance {
    my($parser, $id) = @_;

    my $t = $parser->token;
    if(defined($id) && $t->id ne $id) {
        $parser->_unexpected(value_to_literal($id), $t);
    }

    $parser->near_token($t);

    my $symtab = $parser->symbol_table;

    $t = $parser->next_token;

    if($t->[0] eq 'special') {
        return $parser->token( $symtab->{ $t->[1] } );
    }
    $parser->statement_is_finished( $parser->following_newline );

    $parser->next_token( $parser->look_ahead() );

    my($arity, $value) = @{$t};
    my $proto;

    if( $arity eq "name" && $parser->next_token->[1] eq "=>" ) {
        $arity = "string";
    }

    print STDOUT "[$arity => $value]\n" if _DUMP_TOKEN;

    my @extra;

    if($arity eq "name") {
        $proto = $parser->find($value);
        $arity = $proto->arity;
    }
    elsif($arity eq "operator") {
        $proto = $symtab->{$value};
        if(not defined $proto) {
            $parser->_error("Unknown operator '$value'");
        }
    }
    elsif($arity eq "string" or $arity eq "number") {
        $proto = $symtab->{"(literal)"};
        $arity = "literal";
        push @extra, value => $parser->parse_literal($value);
    }

    if(not defined $proto) {
        Carp::confess("Panic: Unexpected token: $value ($arity)");
    }

    return $parser->token( $proto->clone(
        id    => $value,
        arity => $arity,
        line  => $parser->line,
        @extra,
     ) );
}

sub parse_literal {
    my($parser, $literal) = @_;
    return literal_to_value($literal);
}

sub default_nud {
    my($parser, $symbol) = @_;
    return $symbol; # as is
}

sub default_led {
    my($parser, $symbol) = @_;
    $parser->near_token($parser->token);
    $parser->_error(
        sprintf 'Missing operator (%s): %s',
        $symbol->arity, $symbol->id);
}

sub default_std {
    my($parser, $symbol) = @_;
    $parser->near_token($parser->token);
    $parser->_error(
        sprintf 'Not a statement (%s): %s',
        $symbol->arity, $symbol->id);
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
    my @list;
    while(1) {
        if($parser->token->is_value) {
            push @list, $parser->expression(0);
        }

        if(!$parser->token->is_comma) {
            last;
        }

        $parser->advance(); # comma
    }
    return \@list;
}

sub led_infix {
    my($parser, $symbol, $left) = @_;
    return $parser->binary( $symbol, $left, $parser->expression($symbol->lbp) );
}

sub infix {
    my($parser, $id, $bp, $led) = @_;

    my $symbol = $parser->symbol($id, $bp);
    $symbol->set_led($led || \&led_infix);
    return $symbol;
}

sub led_infixr {
    my($parser, $symbol, $left) = @_;
    return $parser->binary( $symbol, $left, $parser->expression($symbol->lbp - 1) );
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

    my $if = $symbol->clone(arity => 'if');

    $if->first($left);
    $if->second([$parser->expression( $symbol->lbp - 1 )]);
    $parser->advance(":");
    $if->third([$parser->expression( $symbol->lbp - 1 )]);
    return $if;
}

sub is_valid_field {
    my($parser, $token) = @_;
    my $arity = $token->arity;
    if($arity eq "name") {
        return 1;
    }
    elsif($arity eq "literal") {
        return is_int($token->id);
    }
    return 0;
}

sub led_dot {
    my($parser, $symbol, $left) = @_;

    my $t = $parser->token;
    if(!$parser->is_valid_field($t)) {
        $parser->_unexpected("a field name", $t);
    }

    my $dot = $parser->binary($symbol, $left, $t->clone(arity => 'literal'));

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

    my $fetch = $parser->binary($symbol, $left, $parser->expression(0));
    $parser->advance("]");
    return $fetch;
}

sub call {
    my($parser, $proto, $function, @args) = @_;
    if(not ref $function) {
        $function = $proto->clone(
            arity => 'name',
            id    => $function,
        );
    }

    return $proto->clone(
        arity => 'call',
        first => $function,
        second => \@args,
    );
}

sub led_call {
    my($parser, $symbol, $left) = @_;

    my $call = $symbol->clone(arity => 'call');
    $call->first($left);
    $call->second( $parser->expression_list() );
    $parser->advance(")");

    return $call;
}

sub led_bar { # filter
    my($parser, $symbol, $left) = @_;
    # a | b -> b(a)
    return $parser->call($symbol, $parser->expression($symbol->lbp), $left);
}


sub prefix {
    my($parser, $id, $bp, $nud) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->ubp($bp);
    $symbol->set_nud($nud || \&nud_prefix);
    return $symbol;
}

sub nud_prefix {
    my($parser, $symbol) = @_;
    my $un = $symbol->clone(arity => 'unary');
    $parser->reserve($un);
    $un->first($parser->expression($symbol->ubp));
    return $un;
}

sub nud_defined {
    my($parser, $symbol) = @_;
    $parser->reserve( $symbol->clone() );
    return $parser->binary(
        '!=',
        $parser->expression($symbol->ubp),
        $parser->symbol('nil'),
   );
}

sub define_literal{
    my($parser, $id, $value) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->arity('literal');
    $symbol->value($value);
    return $symbol;
}

sub new_scope {
    my($parser) = @_;
    push @{ $parser->scope }, {};
    return;
}

sub pop_scope {
    my($parser) = @_;
    pop @{ $parser->scope };
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
    my $s;
    foreach my $scope(reverse @{$parser->scope}){
        $s = $scope->{$name};
        if(defined $s) {
            return $s;
        }
    }
    $s = $parser->symbol_table->{$name};
    return defined($s) ? $s : $parser->undefined_name($name);
}

sub reserve { # reserve a name to the scope
    my($parser, $symbol) = @_;
    if($symbol->arity ne 'name' or $symbol->is_reserved) {
        return $symbol;
    }

    my $top = $parser->scope->[-1];
    my $t = $top->{$symbol->id};
    if($t) {
        if($t->is_reserved) {
            return $symbol;
        }
        if($t->arity eq "name") {
           $parser->_error("Already defined: $symbol");
        }
    }
    $top->{$symbol->id} = $symbol;
    $symbol->is_reserved(1);
    #$symbol->scope($top);
    return $symbol;
}

sub define { # define a name to the scope
    my($parser, $symbol) = @_;
    my $top = $parser->scope->[-1];

    my $t = $top->{$symbol->id};
    if(defined $t) {
        $parser->_error($t->is_reserved ? "Already is_reserved: $t" : "Already defined: $t");
    }

    $top->{$symbol->id} = $symbol;

    $symbol->is_defined(1);
    $symbol->is_reserved(0);
    $symbol->remove_nud();
    $symbol->remove_led();
    $symbol->remove_std();
    $symbol->lbp(0);
    #$symbol->scope($top);
    return $symbol;
}

sub binary {
    my($parser, $symbol, $lhs, $rhs) = @_;
    if(!ref $symbol) {
        # operator
        $symbol = $parser->symbol($symbol);
    }
    if(!ref $lhs) {
        # literal
        $lhs = $parser->symbol('(literal)')->clone(
            id => $lhs,
        );
    }
    if(!ref $rhs) {
        # literal
        $rhs = $parser->symbol('(literal)')->clone(
            id => $rhs,
        );
    }
    return $symbol->clone(
        arity  => 'binary',
        first  => $lhs,
        second => $rhs,
    );
}

sub nud_name {
    my($parser, $s) = @_;
    return $s->clone(arity => 'name');
}

sub define_function {
    my($parser, @names) = @_;

    foreach my $name(@names) {
        my $s = $parser->symbol($name);
        $s->set_nud(\&nud_name);
    }
    return;
}

sub finish_statement {
    my($parser) = @_;

    my $t = $parser->token;
    if($t->is_block_end or $parser->statement_is_finished) {
        # noop
    }
    elsif($t->id eq ";") {
        $parser->advance();
    }
    else {
        $parser->_unexpected("a semicolon or block end", $t);
    }
   return;
}

sub statement { # process one or more statements
    my($parser) = @_;
    my $t = $parser->token;
    while($t->id eq ";"){
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

    if($expr->is_statement) {
        # expressions can produce statements (e.g. assignment)
        return $expr;
    }
    else {
        return $parser->symbol('print')->clone(
            arity  => 'command',
            first  => [$expr],
            line   => $expr->line,
        );
    }
}

sub statements { # process statements
    my($parser) = @_;
    my @a;

    for(my $t = $parser->token; !$t->is_block_end; $t = $parser->token) {
        push @a, $parser->statement();
    }

    return \@a;
}

sub block {
    my($parser) = @_;
    $parser->new_scope();
    $parser->advance("{");
    my $a = $parser->statements();
    $parser->advance('}');
    $parser->pop_scope();
    return $a;
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

# iterator variables ($~iterator)
# $~iterator . NAME | NAME()
sub nud_iterator {
    my($parser, $symbol) = @_;

    my $iterator = $symbol->clone();
    if($parser->token->id eq ".") {
        $parser->advance();

        my $t = $parser->token;
        if(!any_in($t->arity, qw(variable name))) {
            $parser->_unexpected("a field name", $t);
        }

        my $generator = $parser->iterator_element->{$t->id};
        if(!$generator) {
            $parser->_error("Undefined iterator element: $t");
        }

        $parser->advance(); # element name

        my $args;
        if($parser->token->id eq "(") {
            $parser->advance();
            $args = $parser->expression_list();
            $parser->advance(")");
        }

        $iterator->second($t);
        return $generator->($parser, $iterator, @{$args});
    }
    return $iterator;
}

sub nud_constant {
    my($parser, $symbol) = @_;
    my $t = $parser->token;

    my $expect =  $symbol->id eq 'constant' ? 'name'
                : $symbol->id eq 'my'       ? 'variable'
                :  die "Oops: $symbol";

    if($t->arity ne $expect) {
        $parser->_unexpected("a $expect", $t);
    }
    $parser->define($t)->arity("name");

    $parser->advance();
    $parser->advance("=");

    return $symbol->clone(
        arity        => 'constant',
        first        => $t,
        second       => $parser->expression(0),
        is_statement => 1,
    );
}

my $lambda_id = 0;
sub lambda {
    my($parser, $proto) = @_;
    my $name = $parser->symbol('(name)')->clone(
        id => sprintf('lambda@%d', $lambda_id++),
    );

    return $proto->clone(
        arity => 'proc',
        id    => 'macro',
        first => $name,
    );
}

# -> $x { ... }
sub nud_lambda {
    my($parser, $symbol) = @_;

    my $pointy = $parser->lambda($symbol);

    $parser->new_scope();
    my @params;
    if($parser->token->id ne "{") { # has params
        my $paren = ($parser->token->id eq "(");

        $parser->advance("(") if $paren; # optional

        my $t = $parser->token;
        while($t->arity eq "variable") {
            push @params, $t;
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
    $pointy->second( \@params );

    $parser->advance("{");
    $pointy->third($parser->statements());
    $parser->advance("}");
    $parser->pop_scope();

    return $symbol->clone(
        arity => 'lambda',
        first => $pointy,
    );
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
    my($parser, $pointy, $in_for) = @_;

    my @params;

    $parser->new_scope();

    if($parser->token->id eq "->") {
        $parser->advance();
        if($parser->token->id ne "{") {
            my $paren = ($parser->token->id eq "(");

            $parser->advance("(") if $paren;

            my $t = $parser->token;
            while($t->arity eq "variable") {
                push @params, $t;
                $parser->define($t);

                if($in_for) {
                    $parser->define_iterator($t);
                }

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
    $pointy->second( \@params );

    $parser->advance("{");
    $pointy->third($parser->statements());
    $parser->advance("}");
    $parser->pop_scope();

    return;
}

sub iterator_name {
    my($parser, $var) = @_;
    # $foo -> $~foo
    (my $it_name = $var->id) =~ s/\A (\$?) /${1}~/xms;
    return $it_name;
}

sub define_iterator {
    my($parser, $var) = @_;

    my $it = $parser->symbol( $parser->iterator_name($var) )->clone(
        arity => 'iterator',
        first => $var,
    );
    $parser->define($it);
    $it->set_nud(\&nud_iterator);
    return $it;
}

sub std_for {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'for');
    $proc->first( $parser->expression(0) );
    $parser->pointy($proc, 1);
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

    my $macro = $symbol->clone(arity => "proc");
    my $name  = $parser->token;
    if($name->arity ne "name") {
        $parser->_unexpected("a name", $name);
    }

    $parser->define_function($name->id);
    $macro->first( $parser->symbol($name->id)->nud($parser) );
    $parser->advance();
    $parser->pointy($macro);
    return $macro;
}

sub std_macro_block {
    my($parser, $symbol) = @_;

    my $macro = $parser->std_proc($symbol);

    my $call  = $parser->call($symbol, $macro->first);

    # The "block" keyword defines raw macros.
    # see _generate_proc()
    my $print = $parser->symbol('print_raw')->clone(
        arity => 'command',
        first => [$call],
    );
    # std() returns a list
    return( $macro, $print );
}

sub std_override { # synonym to 'around'
    my($parser, $symbol) = @_;

    return $parser->std_proc($symbol->clone(id => 'around'));
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
            ? [$parser->statement()]
            :  $parser->block());
    }
    return $top_if;
}

sub std_given {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'given');
    $proc->first( $parser->expression(0) );

    local $parser->{in_given} = 1;
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
            $parser->_unexpected("when blocks", $when);
        }
        $when->arity("if");

        if(defined(my $test = $when->first)) { # when
            if(!$test->is_logical) {
                $when->first( $parser->binary('~~', $topic, $test) );
            }
        }
        else { # default
            $when->first( $parser->symbol('true') );
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
    if(defined $else) { # default
        if(defined $elsif) {
            $elsif->third([$else]);
        }
        else {
            $if = $else; # only default
        }
    }
    $proc->third(defined $if ? [$if] : undef);
    return $proc;
}

# when/default
sub std_when {
    my($parser, $symbol) = @_;

    if(!$parser->in_given) {
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

sub barename {
    my($parser) = @_;

    my $t = $parser->token;
    if(!any_in($t->arity, qw(name literal))) {
        $parser->_unexpected("a name or string literal", $t)
    }

    # "string" is ok
    if($t->arity eq 'literal') {
        $parser->advance();
        return $t;
    }

    # package::name
    my @parts;
    push @parts, $t;
    $parser->advance();

    while(1) {
        my $t = $parser->token;

        if($t->id eq "::") {
            $t = $parser->advance(); # "::"

            if($t->arity ne "name") {
                $parser->_unexpected("a name", $t);
            }

            push @parts, $t;
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
        $parser->new_scope();
        my $vars = $parser->expression_list();
        $parser->pop_scope();
        $parser->advance("}");
        return $vars;
    }
    return undef;
}

sub std_cascade {
    my($parser, $symbol) = @_;

    my $base;
    if($parser->token->id ne "with") {
        $base = $parser->barename();
    }

    my $components;
    if($parser->token->id eq "with") {
        $parser->advance(); # "with"

        my @c = $parser->barename();
        while($parser->token->id eq ",") {
            $parser->advance(); # ","
            push @c, $parser->barename();
        }
        $components = \@c;
    }

    my $vars = $parser->localize_vars();

    $parser->finish_statement();
    return $symbol->clone(
        arity  => 'cascade',
        first  => $base,
        second => $components,
        third  => $vars,
    );
}

# markers for the compiler
sub std_marker {
    my($parser, $symbol) = @_;
    $parser->finish_statement();
    return $symbol->clone(arity => 'marker');
}

# iterator elements

sub bad_iterator_args {
    my($parser, $iterator) = @_;
    $parser->_error("Wrong number of arguments for $iterator." . $iterator->second);
}

sub iterator_index {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator
    return $iterator;
}

sub iterator_count {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator + 1
    return $parser->binary('+', $iterator, 1);
}

sub iterator_is_first {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator == 0
    return $parser->binary('==', $iterator, 0);
}

sub iterator_is_last {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator == $~iterator.max_index
    return $parser->binary('==', $iterator, $parser->iterator_max_index($iterator));
}

sub iterator_body {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator.body
    return $iterator->clone(
        arity => 'iterator_body',
    );
}

sub iterator_size {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator.max_index + 1
    return $parser->binary('+', $parser->iterator_max_index($iterator), 1);
}

sub iterator_max_index {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # __builtin_max_index($~iterator.body)
    return $parser->symbol('max_index')->clone(
        arity => 'unary',
        first => $parser->iterator_body($iterator),
    );
}

sub _iterator_peek {
    my($parser, $iterator, $pos) = @_;
    # $~iterator.body[ $~iterator.index + $pos ]
    return $parser->binary('[',
        $parser->iterator_body($iterator),
        $parser->binary('+', $parser->iterator_index($iterator), $pos),
    );
}

sub iterator_peek_next {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    return $parser->_iterator_peek($iterator, +1);
}

sub iterator_peek_prev {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args != 0;
    # $~iterator.is_first ? nil : <prev>
    return $parser->symbol('?')->clone(
        arity  => 'if',
        first  => $parser->iterator_is_first($iterator),
        second => [$parser->symbol('nil')],
        third  => [$parser->_iterator_peek($iterator, -1)],
    );
}

sub iterator_cycle {
    my($parser, $iterator, @args) = @_;
    $parser->bad_iterator_args($iterator) if @args < 2;
    # $iterator.cycle("foo", "bar", "baz") makes:
    #   ($tmp = $~iterator % n) == 0 ? "foo"
    # :                    $tmp == 1 ? "bar"
    # :                                "baz"
    $parser->new_scope();

    my $mod = $parser->binary('%', $iterator, scalar @args);

    # for the second time
    my $tmp = $parser->symbol('($cycle)')->clone(arity => 'name');

    # for the first time
    my $cond = $iterator->clone(
        arity        => 'constant',
        first        => $tmp,
        second       => $mod,
    );

    my $parent = $iterator->clone(
        arity  => 'if',
        first  => $parser->binary('==', $cond, 0),
        second => [ $args[0] ],
    );
    my $child  = $parent;

    my $last = pop @args;
    for(my $i = 1; $i < @args; $i++) {
        my $nth = $iterator->clone(
            arity  => 'if',
            id     => "$iterator.cycle: $i",
            first  => $parser->binary('==', $tmp, $i),
            second => [$args[$i]],
        );

        $child->third([$nth]);
        $child = $nth;
    }
    $child->third([$last]);

    $parser->pop_scope();
    return $parent;
}

# utils

sub _unexpected {
    my($parser, $expected, $got) = @_;
    if(defined($got) && $got ne ";") {
        $parser->_error("Expected $expected, but got $got");
     }
     else {
        $parser->_error("Expected $expected");
     }
}

sub _error {
    my($parser, $message, $near) = @_;

    $near ||= $parser->near_token || ";";
    if($near ne ";") {
        $near = sprintf ', near %s', $near->id, $near->arity
            if ref($near);
    }
    else {
        $near = '';
    }
    Carp::croak(sprintf 'Xslate::Parser(%s:%d): %s%s while parsing templates',
        $parser->file, $parser->line, $message, $near);
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
