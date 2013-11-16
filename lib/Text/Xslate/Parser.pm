package Text::Xslate::Parser;
use Mouse;

use Scalar::Util ();

use Text::Xslate::Symbol;
use Text::Xslate::Util qw(
    $DEBUG
    $STRING $NUMBER
    is_int any_in
    neat
    literal_to_value
    make_error
    p
);

use constant _DUMP_PROTO => scalar($DEBUG =~ /\b dump=proto \b/xmsi);
use constant _DUMP_TOKEN => scalar($DEBUG =~ /\b dump=token \b/xmsi);

our @CARP_NOT = qw(Text::Xslate::Compiler Text::Xslate::Symbol);

my $CODE    = qr/ (?: $STRING | [^'"] ) /xms;
my $COMMENT = qr/\# [^\n;]* (?= [;\n] | \z)/xms;

# Operator tokens that the parser recognizes.
# All the single characters are tokenized as an operator.
my $OPERATOR_TOKEN = sprintf '(?:%s|[^ \t\r\n])', join('|', map{ quotemeta } qw(
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
    +| +& +^ +< +> +~
), ',');

my %shortcut_table = (
    '=' => 'print',
);

my $CHOMP_FLAGS = qr/-/xms;


has identity_pattern => (
    is  => 'ro',
    isa => 'RegexpRef',

    builder  => '_build_identity_pattern',
    init_arg => undef,
);

sub _build_identity_pattern {
    return qr/(?: (?:[A-Za-z_]|\$\~?) [A-Za-z0-9_]* )/xms;
}

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
    is  => 'ro',
    isa => 'HashRef',

    lazy     => 1,
    builder  => '_build_iterator_element',

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

has statement_is_finished => (
    is  => 'rw',
    isa => 'Bool',

    init_arg => undef,
);

has following_newline => (
    is  => 'rw',
    isa => 'Int',

    default  => 0,
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
    builder => '_build_line_start',
);
sub _build_line_start { ':' }

has tag_start => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_tag_start',
);
sub _build_tag_start { '<:' }

has tag_end => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_tag_end',
);
sub _build_tag_end { ':>' }

has comment_pattern => (
    is      => 'ro',
    isa     => 'RegexpRef',
    builder => '_build_comment_pattern',
);
sub _build_comment_pattern { $COMMENT }

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
    required => 0,
);

has line => (
    is       => 'rw',
    required => 0,
);

has input_layer => (
    is => 'ro',
    default => ':utf8',
);

sub symbol_class() { 'Text::Xslate::Symbol' }

# the entry point
sub parse {
    my($parser, $input, %args) = @_;

    local $parser->{file}     = $args{file} || \$input;
    local $parser->{line}     = $args{line} || 1;
    local $parser->{in_given} = 0;
    local $parser->{scope}        = [ map { +{ %{$_} } } @{ $parser->scope } ];
    local $parser->{symbol_table} = { %{ $parser->symbol_table } };
    local $parser->{near_token};
    local $parser->{next_token};
    local $parser->{token};
    local $parser->{input};

    $parser->input( $parser->preprocess($input) );

    $parser->next_token( $parser->tokenize() );
    $parser->advance();
    my $ast = $parser->statements();

    if(my $input_pos = pos $parser->{input}) {
        if($input_pos != length($parser->{input})) {
            $parser->_error("Syntax error", $parser->token);
        }
    }

    return $ast;
}

sub trim_code {
    my($parser, $s) = @_;

    $s =~ s/\A [ \t]+      //xms;
    $s =~ s/   [ \t]+ \n?\z//xms;

    return $s;
}

sub auto_chomp {
    my($parser, $tokens_ref, $i, $s_ref) = @_;

    my $p;
    my $nl = 0;

    # postchomp
    if($i >= 1
            and ($p = $tokens_ref->[$i-1])->[0] eq 'postchomp') {
        # [ CODE ][*][ TEXT    ]
        # <: ...  -:>  \nfoobar
        #            ^^^^
        ${$s_ref} =~ s/\A [ \t]* (\n)//xms;
        if($1) {
            $nl++;
        }
    }

    # prechomp
    if(($i+1) < @{$tokens_ref}
            and ($p = $tokens_ref->[$i+1])->[0] eq 'prechomp') {
        if(${$s_ref} !~ / [^ \t] /xms) {
            #   HERE
            # [ TEXT ][*][ CODE ]
            #         <:- ...  :>
            # ^^^^^^^^
            ${$s_ref} = '';
        }
        else {
            #   HERE
            # [ TEXT ][*][ CODE ]
            #       \n<:- ...  :>
            #       ^^
            $nl += chomp ${$s_ref};
        }
    }
    elsif(($i+2) < @{$tokens_ref}
            and ($p = $tokens_ref->[$i+2])->[0] eq 'prechomp'
            and ($p = $tokens_ref->[$i+1])->[0] eq 'text'
            and $p->[1] !~ / [^ \t] /xms) {
        #   HERE
        # [ TEXT ][ TEXT ][*][ CODE ]
        #       \n        <:- ...  :>
        #       ^^^^^^^^^^
        $p->[1] = '';
        $nl += (${$s_ref} =~ s/\n\z//xms);
    }
    return $nl;
}

# split templates by tags before tokenizing
sub split :method {
    my $parser  = shift;
    local($_) = @_;

    my @tokens;

    my $line_start    = $parser->line_start;
    my $tag_start     = $parser->tag_start;
    my $tag_end       = $parser->tag_end;

    my $lex_line_code = defined($line_start)
        && qr/\A ^ [ \t]* \Q$line_start\E ([^\n]* \n?) /xms;

    my $lex_tag_start = qr/\A \Q$tag_start\E ($CHOMP_FLAGS?)/xms;

    # 'text' is a something without newlines
    # following a newline, $tag_start, or end of the input
    my $lex_text = qr/\A ( [^\n]*? (?: \n | (?= \Q$tag_start\E ) | \z ) ) /xms;

    my $lex_comment = $parser->comment_pattern;
    my $lex_code    = qr/(?: $lex_comment | $CODE )/xms;

    my $in_tag = 0;

    while($_) {
        if($in_tag) {
            my $start = 0;
            my $pos;
            while( ($pos = index $_, $tag_end, $start) >= 0 ) {
                my $code = substr $_, 0, $pos;
                $code =~ s/$lex_code//xmsg;
                if(length($code) == 0) {
                    last;
                }
                $start = $pos + 1;
            }

            if($pos >= 0) {
                my $code = substr $_, 0, $pos, '';
                $code =~ s/($CHOMP_FLAGS?) \z//xmso;
                my $chomp = $1;

                s/\A \Q$tag_end\E //xms or die "Oops!";

                push @tokens, [ code => $code ];
                if($chomp) {
                    push @tokens, [ postchomp => $chomp ];
                }
                $in_tag = 0;
            }
            else {
                last; # the end tag is not found
            }
        }
        # not $in_tag
        elsif($lex_line_code
                && (@tokens == 0 || $tokens[-1][1] =~ /\n\z/xms)
                && s/$lex_line_code//xms) {
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
            push @tokens, [ text => $1 ];
        }
        else {
            confess "Oops: Unreached code, near" . p($_);
        }
    }

    if($in_tag) {
        # calculate line number
        my $orig_src = $_[0];
        substr $orig_src, -length($_), length($_), '';
        my $line = ($orig_src =~ tr/\n/\n/);
        $parser->_error("Malformed templates detected",
            neat((split /\n/, $_)[0]), ++$line,
        );
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
            my $nl = $parser->auto_chomp($tokens_ref, $i, \$s);

            $s =~ s/(["\\])/\\$1/gxms; # " for poor editors

            # $s may have single new line
            $nl += ($s =~ s/\n/\\n/xms);

            $code .= qq{print_raw "$s";}; # must set even if $s is empty
            $code .= qq{\n} if $nl > 0;
        }
        elsif($type eq 'code') {
            # shortcut commands
            $s =~ s/$shortcut_rx/$shortcut_table->{$1}/xms
                if $shortcut;

            $s = $parser->trim_code($s);

            if($s =~ /\A \s* [}] \s* \z/xms){
                $code .= $s;
            }
            elsif($s =~ s/\n\z//xms) {
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

sub BUILD {
    my($parser) = @_;
    $parser->_init_basic_symbols();
    $parser->init_symbols();
    return;
}

# The grammer

sub _init_basic_symbols {
    my($parser) = @_;

    $parser->symbol('(end)')->is_block_end(1); # EOF

    # prototypes of value symbols
    foreach my $type (qw(name variable literal)) {
        my $s = $parser->symbol("($type)");
        $s->arity($type);
        $s->set_nud( $parser->can("nud_$type") );
    }

    # common separators
    $parser->symbol(';')->set_nud(\&nud_separator);
    $parser->define_pair('(' => ')');
    $parser->define_pair('{' => '}');
    $parser->define_pair('[' => ']');
    $parser->symbol(',')  ->is_comma(1);
    $parser->symbol('=>') ->is_comma(1);

    # common commands
    $parser->symbol('print')    ->set_std(\&std_print);
    $parser->symbol('print_raw')->set_std(\&std_print);

    # special literals
    $parser->define_literal(nil   => undef);
    $parser->define_literal(true  => 1);
    $parser->define_literal(false => 0);

    # special tokens
    $parser->symbol('__FILE__')->set_nud(\&nud_current_file);
    $parser->symbol('__LINE__')->set_nud(\&nud_current_line);
    $parser->symbol('__ROOT__')->set_nud(\&nud_current_vars);

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

    $parser->prefix('!',  200)->is_logical(1);
    $parser->prefix('+',  200);
    $parser->prefix('-',  200);
    $parser->prefix('+^', 200); # numeric bitwise negate

    $parser->infix('*',  190);
    $parser->infix('/',  190);
    $parser->infix('%',  190);
    $parser->infix('x',  190);
    $parser->infix('+&', 190); # numeric bitwise and

    $parser->infix('+',  180);
    $parser->infix('-',  180);
    $parser->infix('~',  180); # connect
    $parser->infix('+|', 180); # numeric bitwise or
    $parser->infix('+^', 180); # numeric bitwise xor


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

    $parser->infix('|',  140, \&led_pipe);

    $parser->infix('&&', 130)->is_logical(1);

    $parser->infix('||', 120)->is_logical(1);
    $parser->infix('//', 120)->is_logical(1);
    $parser->infix('min', 120);
    $parser->infix('max', 120);

    $parser->infix('..', 110, \&led_range);

    $parser->symbol(':');
    $parser->infixr('?', 100, \&led_ternary);

    $parser->assignment('=',   90);
    $parser->assignment('+=',  90);
    $parser->assignment('-=',  90);
    $parser->assignment('*=',  90);
    $parser->assignment('/=',  90);
    $parser->assignment('%=',  90);
    $parser->assignment('~=',  90);
    $parser->assignment('&&=', 90);
    $parser->assignment('||=', 90);
    $parser->assignment('//=', 90);

    $parser->make_alias('!'  => 'not')->ubp(70);
    $parser->make_alias('&&' => 'and')->lbp(60);
    $parser->make_alias('||' => 'or') ->lbp(50);
    return;
}

sub init_symbols {
    my($parser) = @_;
    my $s;

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
    $s = $parser->symbol('if');
    $s->set_std(\&std_if);
    $s->can_be_modifier(1);

    $parser->symbol('for')      ->set_std(\&std_for);
    $parser->symbol('while' )   ->set_std(\&std_while);
    $parser->symbol('given')    ->set_std(\&std_given);
    $parser->symbol('when')     ->set_std(\&std_when);
    $parser->symbol('default')  ->set_std(\&std_when);

    $parser->symbol('include')  ->set_std(\&std_include);

    $parser->symbol('last')  ->set_std(\&std_last);
    $parser->symbol('next')  ->set_std(\&std_next);

    # macros

    $parser->symbol('cascade')  ->set_std(\&std_cascade);
    $parser->symbol('macro')    ->set_std(\&std_proc);
    $parser->symbol('around')   ->set_std(\&std_proc);
    $parser->symbol('before')   ->set_std(\&std_proc);
    $parser->symbol('after')    ->set_std(\&std_proc);
    $parser->symbol('block')    ->set_std(\&std_macro_block);
    $parser->symbol('super')    ->set_std(\&std_super);
    $parser->symbol('override') ->set_std(\&std_override);

    $parser->symbol('->')       ->set_nud(\&nud_lambda);

    # lexical variables/constants stuff
    $parser->symbol('constant')->set_nud(\&nud_constant);
    $parser->symbol('my'      )->set_nud(\&nud_constant);

    return;
}

sub _build_iterator_element {
    return {
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
    };
}


sub symbol {
    my($parser, $id, $lbp) = @_;

    my $stash = $parser->symbol_table;
    my $s     = $stash->{$id};
    if(defined $s) {
        if(defined $lbp) {
            $s->lbp($lbp);
        }
    }
    else { # create a new symbol
        $s = $parser->symbol_class->new(id => $id, lbp => $lbp || 0);
        $stash->{$id} = $s;
    }

    return $s;
}

sub define_pair {
    my($parser, $left, $right) = @_;
    $parser->symbol($left) ->counterpart($right);
    $parser->symbol($right)->counterpart($left);
    return;
}

# the low-level tokenizer. Don't use it directly, use advance() instead.
sub tokenize {
    my($parser) = @_;

    local *_ = \$parser->{input};

    my $comment_rx = $parser->comment_pattern;
    my $id_rx      = $parser->identity_pattern;
    my $count      = 0;
    TRY: {
        /\G (\s*) /xmsgc;
        $count += ( $1 =~ tr/\n/\n/);
        $parser->following_newline( $count );

        if(/\G $comment_rx /xmsgc) {
            redo TRY; # retry
        }
        elsif(/\G ($id_rx)/xmsgc){
            return [ name => $1 ];
        }
        elsif(/\G ($NUMBER | $STRING)/xmsogc){
            return [ literal => $1 ];
        }
        elsif(/\G ($OPERATOR_TOKEN)/xmsogc){
            return [ operator => $1 ];
        }
        elsif(/\G (\S+)/xmsgc) {
            Carp::confess("Oops: Unexpected token '$1'");
        }
        else { # empty
            return [ special => '(end)' ];
        }
    }
}

sub next_token_is {
    my($parser, $token) = @_;
    return $parser->next_token->[1] eq $token;
}

# the high-level tokenizer
sub advance {
    my($parser, $expect) = @_;

    my $t = $parser->token;
    if(defined($expect) && $t->id ne $expect) {
        $parser->_unexpected(neat($expect), $t);
    }

    $parser->near_token($t);

    my $stash = $parser->symbol_table;

    $t = $parser->next_token;

    if($t->[0] eq 'special') {
        return $parser->token( $stash->{ $t->[1] } );
    }
    $parser->statement_is_finished( $parser->following_newline != 0 );
    my $line = $parser->line( $parser->line + $parser->following_newline );

    $parser->next_token( $parser->tokenize() );

    my($arity, $id) = @{$t};
    if( $arity eq "name" && $parser->next_token_is("=>") ) {
        $arity = "literal";
    }

    print STDOUT "[$arity => $id] #$line\n" if _DUMP_TOKEN;

    my $symbol;
    if($arity eq "literal") {
        $symbol = $parser->symbol('(literal)')->clone(
            id    => $id,
            value => $parser->parse_literal($id)
        );
    }
    elsif($arity eq "operator") {
        $symbol = $stash->{$id};
        if(not defined $symbol) {
            $parser->_error("Unknown operator '$id'");
        }
        $symbol = $symbol->clone(
            arity => $arity, # to make error messages clearer
        );
    }
    else { # name
        # find_or_create() returns a cloned symbol,
        # so there's not need to clone() here
        $symbol = $parser->find_or_create($id);
    }

    $symbol->line($line);
    return $parser->token($symbol);
}

sub parse_literal {
    my($parser, $literal) = @_;
    return literal_to_value($literal);
}

sub nud_name {
    my($parser, $symbol) = @_;
    return $symbol->clone(
        arity => 'name',
    );
}
sub nud_variable {
    my($parser, $symbol) = @_;
    return $symbol->clone(
        arity => 'variable',
    );
}
sub nud_literal {
    my($parser, $symbol) = @_;
    return $symbol->clone(
        arity => 'literal',
    );
}

sub default_nud {
    my($parser, $symbol) = @_;
    return $symbol->clone(); # as is
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

# for left associative infix operators
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

# for right associative infix operators
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

# for prefix operators
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

sub led_assignment {
    my($parser, $symbol, $left) = @_;

    $parser->_error("Assignment ($symbol) is forbidden", $left);
}

sub assignment {
    my($parser, $id, $bp) = @_;

    $parser->symbol($id, $bp)->set_led(\&led_assignment);
    return;
}

# the ternary is a right associative operator
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

    my $dot = $symbol->clone(
        arity  => "field",
        first  => $left,
        second => $t->clone(arity => 'literal'),
    );

    $t = $parser->advance();
    if($t->id eq "(") {
        $parser->advance(); # "("
        $dot->third( $parser->expression_list() );
        $parser->advance(")");
        $dot->arity("methodcall");
    }

    return $dot;
}

sub led_fetch { # $h[$field]
    my($parser, $symbol, $left) = @_;

    my $fetch = $symbol->clone(
        arity  => "field",
        first  => $left,
        second => $parser->expression(0),
    );
    $parser->advance("]");
    return $fetch;
}

sub call {
    my($parser, $function, @args) = @_;
    if(not ref $function) {
        $function = $parser->symbol('(name)')->clone(
            arity => 'name',
            id    => $function,
            line  => $parser->line,
        );
    }

    return $parser->symbol('(call)')->clone(
        arity  => 'call',
        first  => $function,
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

sub led_pipe { # filter
    my($parser, $symbol, $left) = @_;
    # a | b -> b(a)
    return $parser->call($parser->expression($symbol->lbp), $left);
}

sub led_range { # x .. y
    my($parser, $symbol, $left) = @_;
    return $symbol->clone(
        arity  => 'range',
        first  => $left,
        second => $parser->expression(0),
    );
}

sub nil {
    my($parser) = @_;
    return $parser->symbol('nil')->nud($parser);
}

sub nud_defined {
    my($parser, $symbol) = @_;
    $parser->reserve( $symbol->clone() );
    # prefix:<defined> is a syntactic sugar to $a != nil
    return $parser->binary(
        '!=',
        $parser->expression($symbol->ubp),
        $parser->nil,
   );
}

# for special literals (e.g. nil, true, false)
sub nud_special {
    my($parser, $symbol) = @_;
    return $symbol->first;
}

sub define_literal { # special literals
    my($parser, $id, $value) = @_;

    my $symbol = $parser->symbol($id);
    $symbol->first( $symbol->clone(
        arity => defined($value) ? 'literal' : 'nil',
        value => $value,
    ) );
    $symbol->set_nud(\&nud_special);
    $symbol->is_defined(1);
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
        return $parser->symbol_table->{'(variable)'}->clone(
            id => $name,
        );
    }
    else {
        return $parser->symbol_table->{'(name)'}->clone(
            id => $name,
        );
    }
}

sub find_or_create { # find a name from all the scopes
    my($parser, $name) = @_;
    my $s;
    foreach my $scope(reverse @{$parser->scope}){
        $s = $scope->{$name};
        if(defined $s) {
            return $s->clone();
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

sub print {
    my($parser, @args) = @_;
    return $parser->symbol('print')->clone(
        arity => 'print',
        first => \@args,
        line  => $parser->line,
    );
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

sub define_function {
    my($parser, @names) = @_;

    foreach my $name(@names) {
        my $s = $parser->symbol($name);
        $s->set_nud(\&nud_name);
        $s->is_defined(1);
    }
    return;
}

sub finish_statement {
    my($parser, $expr) = @_;

    my $t = $parser->token;
    if($t->can_be_modifier) {
        $parser->advance();
        $expr = $t->std($parser, $expr);
        $t    = $parser->token;
    }

    if($t->is_block_end or $parser->statement_is_finished) {
        # noop
    }
    elsif($t->id eq ";") {
        $parser->advance();
    }
    else {
        $parser->_unexpected("a semicolon or block end", $t);
    }
   return $expr;
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

        # std() can return a list of nodes
        return $t->std($parser);
    }

    my $expr = $parser->auto_command( $parser->expression(0) );
    return $parser->finish_statement($expr);
}

sub auto_command {
    my($parser, $expr) = @_;
    if($expr->is_statement) {
        # expressions can produce pure statements (e.g. assignment )
        return $expr;
    }
    else {
        return $parser->print($expr);
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
    $parser->advance("}");
    $parser->pop_scope();
    return $a;
}

sub nud_paren {
    my($parser, $symbol) = @_;
    my $expr = $parser->expression(0);
    $parser->advance( $symbol->counterpart );
    return $expr;
}

# for object literals
sub nud_brace {
    my($parser, $symbol) = @_;

    my $list = $parser->expression_list();

    $parser->advance($symbol->counterpart);
    return $symbol->clone(
        arity => 'composer',
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

        my $generator = $parser->iterator_element->{$t->value};
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
        id   => sprintf('lambda@%s:%d', $parser->file, $lambda_id++),
    );

    return $parser->symbol('(name)')->clone(
        arity => 'proc',
        id    => 'macro',
        first => $name,
        line  => $proto->line,
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

sub nud_current_file {
    my($self, $symbol) = @_;
    my $file = $self->file;
    return $symbol->clone(
        arity => 'literal',
        value => ref($file) ? '<string>' : $file,
    );
}

sub nud_current_line {
    my($self, $symbol) = @_;
    return $symbol->clone(
        arity => 'literal',
        value => $symbol->line,
    );
}

sub nud_current_vars {
    my($self, $symbol) = @_;
    return $symbol->clone(
        arity => 'vars',
    );
}

sub nud_separator {
    my($self, $symbol) = @_;
    $self->_error("Invalid expression found", $symbol);
}

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

    # for-else support
    if($parser->token eq 'else') {
        $parser->advance();
        my $else = $parser->block();
        $proc = $symbol->clone( arity => 'for_else',
            first  => $proc,
            second => $else,
        )
    }
    return $proc;
}

sub std_while {
    my($parser, $symbol) = @_;

    my $proc = $symbol->clone(arity => 'while');
    $proc->first( $parser->expression(0) );
    $parser->pointy($proc);
    return $proc;
}

# macro name -> { ... }
sub std_proc {
    my($parser, $symbol) = @_;

    my $macro = $symbol->clone(arity => "proc");
    my $name  = $parser->token;

    if($name->arity ne "name") {
        $parser->_unexpected("a name", $name);
    }

    $parser->define_function($name->id);
    $macro->first($name);
    $parser->advance();
    $parser->pointy($macro);
    return $macro;
}

# block name -> { ... }
# block name | filter -> { ... }
sub std_macro_block {
    my($parser, $symbol) = @_;

    my $macro = $symbol->clone(arity => "proc");
    my $name  = $parser->token;

    if($name->arity ne "name") {
        $parser->_unexpected("a name", $name);
    }

    # auto filters
    my @filters;
    my $t = $parser->advance();
    while($t->id eq "|") {
        $t = $parser->advance();

        if($t->arity ne "name") {
            $parser->_unexpected("a name", $name);
        }
        my $filter = $t->clone();
        $t = $parser->advance();

        my $args;
        if($t->id eq "(") {
            $parser->advance();
            $args = $parser->expression_list();
            $t = $parser->advance(")");
        }
        push @filters, $args
            ? $parser->call($filter, @{$args})
            : $filter;
    }

    $parser->define_function($name->id);
    $macro->first($name);
    $parser->pointy($macro);

    my $call = $parser->call($macro->first);
    if(@filters) {
        foreach my $filter(@filters) { # apply filters
            $call = $parser->call($filter, $call);
        }
    }
    # std() can return a list
    return( $macro, $parser->print($call) );
}

sub std_override { # synonym to 'around'
    my($parser, $symbol) = @_;

    return $parser->std_proc($symbol->clone(id => 'around'));
}

sub std_if {
    my($parser, $symbol, $expr) = @_;

    my $if = $symbol->clone(arity => "if");

    $if->first( $parser->expression(0) );

    if(defined $expr) { # statement modifier
        $if->second([$expr]);
        return $if;
    }

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

    my $given = $symbol->clone(arity => 'given');
    $given->first( $parser->expression(0) );

    local $parser->{in_given} = 1;
    $parser->pointy($given);

    if(!(defined $given->second && @{$given->second})) { # if no topic vars
        $given->second([
            $parser->symbol('($_)')->clone(arity => 'variable' )
        ]);
    }

    $parser->build_given_body($given, "when");
    return $given;
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

sub _only_white_spaces {
    my($s) = @_;
    return  $s->arity eq "literal"
         && $s->value =~ m{\A [ \t\r\n]* \z}xms
}

sub build_given_body {
    my($parser, $given, $expect) = @_;
    my($topic) = @{$given->second};

    # make if-elsif-else chain from given-when
    my $if;
    my $elsif;
    my $else;
    foreach my $when(@{$given->third}) {
        if($when->arity ne $expect) {
            # ignore white space
            if($when->id eq "print_raw"
                    && !grep { !_only_white_spaces($_) } @{$when->first}) {
                next;
            }
            $parser->_unexpected("$expect blocks", $when);
        }
        $when->arity("if"); # change the arity

        if(defined(my $test = $when->first)) { # when
            if(!$test->is_logical) {
                $when->first( $parser->binary('~~', $topic, $test) );
            }
        }
        else { # default
            $when->first( $parser->symbol('true')->nud($parser) );
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
    $given->third(defined $if ? [$if] : undef);
    return;
}

sub std_include {
    my($parser, $symbol) = @_;

    my $arg  = $parser->barename();
    my $vars = $parser->localize_vars();
    my $stmt = $symbol->clone(
        first  => $arg,
        second => $vars,
        arity  => 'include',
    );
    return $parser->finish_statement($stmt);
}

sub std_print {
    my($parser, $symbol) = @_;
    my $args;
    if($parser->token->id ne ";") {
        $args = $parser->expression_list();
    }
    my $stmt = $symbol->clone(
        arity => 'print',
        first => $args,
    );
    return $parser->finish_statement($stmt);
}

# for cascade() and include()
sub barename {
    my($parser) = @_;

    my $t = $parser->token;
    if($t->arity ne 'name' or $t->is_defined) {
        # string literal for 'cascade', or any expression for 'include'
        return $parser->expression(0);
    }

    # path::to::name
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

# NOTHING | { expression-list }
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
    my $stmt = $symbol->clone(
        arity  => 'cascade',
        first  => $base,
        second => $components,
        third  => $vars,
    );
    return $parser->finish_statement($stmt);
}

sub std_super {
    my($parser, $symbol) = @_;
    my $stmt = $symbol->clone(arity => 'super');
    return $parser->finish_statement($stmt);
}

sub std_next {
    my($parser, $symbol) = @_;
    my $stmt = $symbol->clone(arity => 'loop_control', id => 'next');
    return $parser->finish_statement($stmt);
}

sub std_last {
    my($parser, $symbol) = @_;
    my $stmt = $symbol->clone(arity => 'loop_control', id => 'last');
    return $parser->finish_statement($stmt);
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
        second => [$parser->nil],
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

sub make_alias { # alas(from => to)
    my($parser, $from, $to) = @_;

    my $stash = $parser->symbol_table;
    if(exists $parser->symbol_table->{$to}) {
        Carp::confess(
            "Cannot make an alias to an existing symbol ($from => $to / "
            . p($parser->symbol_table->{$to}) .")");
    }

    # make a snapshot
    return $stash->{$to} = $parser->symbol($from)->clone(
        value => $to, # real id
    );
}

sub not_supported {
    my($parser, $symbol) = @_;
    $parser->_error("'$symbol' is not supported");
}

sub _unexpected {
    my($parser, $expected, $got) = @_;
    if(defined($got) && $got ne ";") {
        if($got eq '(end)') {
            $parser->_error("Expected $expected, but reached EOF");
        }
        else {
            $parser->_error("Expected $expected, but got " . neat("$got"));
        }
     }
     else {
        $parser->_error("Expected $expected");
     }
}

sub _error {
    my($parser, $message, $near, $line) = @_;

    $near ||= $parser->near_token || ";";
    if($near ne ";" && $message !~ /\b \Q$near\E \b/xms) {
        $message .= ", near $near";
    }
    die $parser->make_error($message . ", while parsing templates",
        $parser->file, $line || $parser->line);
}

no Mouse;
__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::Parser - The base class of template parsers

=head1 DESCRIPTION

This is a parser to build the abstract syntax tree from templates.

The basis of the parser is Top Down Operator Precedence.

=head1 SEE ALSO

L<http://javascript.crockford.com/tdop/tdop.html> - Top Down Operator Precedence (Douglas Crockford)

L<Text::Xslate>

L<Text::Xslate::Compiler>

L<Text::Xslate::Symbol>

=cut
