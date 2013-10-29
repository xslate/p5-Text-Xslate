package Text::Xslate::Compiler;
use Mouse;
use Mouse::Util::TypeConstraints;

use Scalar::Util ();
use Carp         ();

use Text::Xslate::Parser;
use Text::Xslate::Util qw(
    $DEBUG
    value_to_literal
    is_int any_in
    make_error
    p
);

#use constant _VERBOSE  => scalar($DEBUG =~ /\b verbose \b/xms);
use constant {
    _DUMP_ASM => scalar($DEBUG =~ /\b dump=asm \b/xms),
    _DUMP_AST => scalar($DEBUG =~ /\b dump=ast \b/xms),
    _DUMP_GEN => scalar($DEBUG =~ /\b dump=gen \b/xms),
    _DUMP_CAS => scalar($DEBUG =~ /\b dump=cascade \b/xms),

    _OP_NAME    => 0,
    _OP_ARG     => 1,
    _OP_LINE    => 2,
    _OP_FILE    => 3,
    _OP_LABEL   => 4,
    _OP_COMMENT => 5,

    _FOR_LOOP   => 1,
    _WHILE_LOOP => 2,
};


our $OPTIMIZE = scalar(($DEBUG =~ /\b optimize=(\d+) \b/xms)[0]);
if(not defined $OPTIMIZE) {
    $OPTIMIZE = 1; # enable optimization by default
}

our @CARP_NOT = qw(Text::Xslate Text::Xslate::Parser);

{
    package Text::Xslate;
    our %OPS; # to avoid 'once' warnings;
}

my %binary = (
    '==' => 'eq',
    '!=' => 'ne',
    '<'  => 'lt',
    '<=' => 'le',
    '>'  => 'gt',
    '>=' => 'ge',

    '~~'  => 'match',

    '<=>' => 'ncmp',
    'cmp' => 'scmp',

    '+'  => 'add',
    '-'  => 'sub',
    '*'  => 'mul',
    '/'  => 'div',
    '%'  => 'mod',

    '~'  => 'concat',
    'x'  => 'repeat',

    '+|' => 'bitor',
    '+&' => 'bitand',
    '+^' => 'bitxor',

    'min' => 'lt', # a < b ? a : b
    'max' => 'gt', # a > b ? a : b

    '['  => 'fetch_field',
);
my %logical_binary = (
    '&&'  => 'and',
    '||'  => 'or',
    '//'  => 'dor',
);

my %unary = (
    '!'   => 'not',
    '+'   => 'noop',
    '-'   => 'minus',
    '+^'  => 'bitneg',

    'max_index' => 'max_index', # for loop context vars
);

my %goto_family = map { $_ => undef } qw(
    for_iter
    and
    dand
    or
    dor
    goto
);

my %builtin = (
    'html_escape'  => ['builtin_html_escape',
                        \&Text::Xslate::Util::html_escape],
    'uri_escape'   => ['builtin_uri_escape',
                        \&Text::Xslate::Util::uri_escape],
    'mark_raw'     => ['builtin_mark_raw',
                        \&Text::Xslate::Util::mark_raw],
    'unmark_raw'   => ['builtin_unmark_raw',
                        \&Text::Xslate::Util::unmark_raw],

    'raw'          => ['builtin_mark_raw',
                        \&Text::Xslate::Util::mark_raw],

    'html'         => ['builtin_html_escape',
                        \&Text::Xslate::Util::html_escape],
    'uri'          => ['builtin_uri_escape',
                        \&Text::Xslate::Util::uri_escape],

    'is_array_ref' => ['builtin_is_array_ref',
                        \&Text::Xslate::Util::is_array_ref],
    'is_hash_ref'  => ['builtin_is_hash_ref',
                        \&Text::Xslate::Util::is_hash_ref],
);

has lvar_id => ( # local variable id
    is  => 'rw',
    isa => 'Int',

    init_arg => undef,
);

has lvar => ( # local variable id table
    is  => 'rw',
    isa => 'HashRef[Int]',

    init_arg => undef,
);

has const => (
    is  => 'rw',
    isa => 'ArrayRef',

    init_arg => undef,
);

has macro_table => (
    is  => 'rw',
    isa => 'HashRef',

    predicate => 'has_macro_table',
    init_arg  => undef,
);

has engine => ( # Xslate engine
    is       => 'ro',
    isa      => 'Object',
    required => 0,
    weak_ref => 1,
);

has dependencies => (
    is  => 'ro',
    isa => 'ArrayRef',
    init_arg => undef,
);

has type => (
    is      => 'rw',
    isa     => enum([qw(html xml text)]),
    default => 'html',
);

has syntax => (
    is       => 'rw',

    default  => 'Kolon',
);

has parser_option => (
    is       => 'rw',
    isa      => 'HashRef',

    default  => sub { {} },
);

has parser => (
    is  => 'rw',
    isa => 'Object', # Text::Xslate::Parser

    handles => [qw(define_function)],

    lazy     => 1,
    builder  => '_build_parser',
    init_arg => undef,
);

has input_layer => (
    is      => 'ro',
    default => ':utf8',
);

sub _build_parser {
    my($self) = @_;
    my $syntax = $self->syntax;
    if(ref($syntax)) {
        return $syntax;
    }
    else {
        my $parser_class = Mouse::Util::load_first_existing_class(
            "Text::Xslate::Syntax::" . $syntax,
            $syntax,
        );
        return $parser_class->new(
            %{$self->parser_option},
            engine   => $self->engine,
            compiler => $self,
        );
    }
}

has cascade => (
    is       => 'rw',
    init_arg => undef,
);

has [qw(header footer macro)] => (
    is  => 'rw',
    isa => 'ArrayRef',
);

has current_file => (
    is  => 'rw',

    init_arg => undef,
);

has file => (
    is  => 'rw',

    init_arg => undef,
);

has overridden_builtin => (
    is  => 'ro',
    isa => 'HashRef',

    default => sub { +{} },
);

sub lvar_use {
    my($self, $n) = @_;

    return $self->lvar_id + $n;
}

sub filename {
    my($self) = @_;
    my $file = $self->file;
    return ref($file) ? '<string>' : $file;
}

sub compile {
    my($self, $input, %args) = @_;

    # each compiling process is independent
    local $self->{macro_table}  = {};
    local $self->{lvar_id     } = 0;
    local $self->{lvar}         = {};
    local $self->{const}        = [];
    local $self->{in_loop}      = 0;
    local $self->{dependencies} = [];
    local $self->{cascade};
    local $self->{header}       = $self->{header};
    local $self->{footer}       = $self->{footer};
    local $self->{macro}        = $self->{macro};
    local $self->{current_file} = '<string>'; # for opinfo
    local $self->{file}         = $args{file} || \$input;

    if(my $engine = $self->engine) {
        my $ob = $self->overridden_builtin;
        Internals::SvREADONLY($ob, 0);
        foreach my $name(keys %builtin) {
            my $f = $engine->{function}{$name};
            $ob->{$name} = ( $builtin{$name}[1] != $f ) + 0;
        }
        Internals::SvREADONLY($ob, 1);
    }

    my $parser = $self->parser;

    my $header = delete $self->{header};
    my $footer = delete $self->{footer};
    my $macro = delete $self->{macro};

    if(!$args{omit_augment}) {
        if($header) {
            substr $input, 0, 0, $self->_cat_files($header);
        }
        if($footer) {
            $input .= $self->_cat_files($footer);
        }
    }
    if($macro) {
        if(!grep { $_ eq $self->current_file } @$macro) {
            substr $input, 0, 0, $self->_cat_files($macro);
        }
    }

    my @code; # main code
    {
        my $ast = $parser->parse($input, %args);
        print STDERR p($ast) if _DUMP_AST;
        @code = (
            $self->opcode(set_opinfo => undef, file => $self->current_file, line => 1),
            $self->compile_ast($ast),
            $self->opcode('end'),
        );
    }

    my $cascade = $self->cascade;
    if(defined $cascade) {
        $self->_process_cascade($cascade, \%args, \@code);
    }

    push @code, $self->_flush_macro_table() if $self->has_macro_table;

    if($OPTIMIZE) {
        $self->_optimize_vmcode(\@code) for 1 .. 3;
    }

    print STDERR "// ", $self->filename, "\n",
        $self->as_assembly(\@code, scalar($DEBUG =~ /\b ix \b/xms))
            if _DUMP_ASM;

    {
        my %uniq;
        push @code,
            map  { [ depend => $_ ] }
            grep { !ref($_) and !$uniq{$_}++ } @{$self->dependencies};
    }

    return \@code;
}

sub opcode { # build an opcode
    my($self, $name, $arg, %args) = @_;
    my $symbol = $args{symbol};
    my $file   = $args{file};
    my $label  = $args{label};
    if(not defined $file) {
        $file = $self->filename;
        if(defined $file and $file ne $self->current_file) {
            $self->current_file($file);
        }
        else {
            $file = undef;
        }
    }
    # name, arg, label, line, file, comment
    return [ $name => $arg,
                $args{line} || (ref $symbol ? $symbol->line : undef),
                $file,
                $label,
                $args{comment},
           ];
}

sub push_expr {
    my($self, $node) = @_;

    my $list_op = $node->arity eq 'range';
    my @code = ($self->compile_ast($node));
    if(not $list_op) {
        push @code, $self->opcode('push');
    }
    return @code;
}


sub _cat_files {
    my($self, $files) = @_;
    my $engine = $self->engine || $self->_error("No Xslate engine which header/footer requires");
    my $s = '';
    foreach my $file(@{$files}) {
        my $fullpath = $engine->find_file($file)->{fullpath};
        $s .= $engine->slurp_template( $self->input_layer, $fullpath );
        $self->requires($fullpath);
    }
    return $s;
}

our $_lv = -1;

sub compile_ast {
    my($self, $ast) = @_;
    return if not defined $ast;

    local $_lv = $_lv + 1 if _DUMP_GEN;

    my @code;
    foreach my $node(ref($ast) eq 'ARRAY' ? @{$ast} : $ast) {
        Scalar::Util::blessed($node) or Carp::confess("[BUG] Not a node object: " . p($node));

        printf STDERR "%s"."generate %s (%s)\n", "." x $_lv, $node->arity, $node->id if _DUMP_GEN;

        my $generator = $self->can('_generate_' . $node->arity)
            || Carp::confess("[BUG] Unexpected node:  " . p($node));

        push @code, $self->$generator($node);
    }

    return @code;
}

sub _process_cascade {
    my($self, $cascade, $args, $main_code) = @_;
    printf STDERR "# cascade %s %s", $self->file, $cascade->dump if _DUMP_CAS;
    my $engine = $self->engine
        || $self->_error("Cannot cascade templates without Xslate engine", $cascade);

    my($base_file, $base_code);
    my $base       = $cascade->first;
    my @components = $cascade->second
        ? (map{ $self->_bare_to_file($_) } @{$cascade->second})
        : ();
    my $vars       = $cascade->third;

    if(defined $base) { # pure cascade
        $base_file = $self->_bare_to_file($base);
        $base_code = $engine->load_file($base_file);
        $self->requires( $engine->find_file($base_file)->{fullpath} );
    }
    else { # overlay
        $base_file = $args->{file}; # only for error messages
        $base_code = $main_code;

        if(defined $args->{fullpath}) {
            $self->requires( $args->{fullpath} );
        }

        push @{$main_code}, $self->_flush_macro_table();
    }

    foreach my $cfile(@components) {
        my $code     = $engine->load_file($cfile);
        my $fullpath = $engine->find_file($cfile)->{fullpath};

        my $mtable   = $self->macro_table;
        my $macro;
        foreach my $c(@{$code}) {
            # $c = [name, arg, line, file, symbol ]

            # retrieve macros from assembly code
            if($c->[_OP_NAME] eq 'macro_begin' .. $c->[_OP_NAME] eq 'macro_end') {
                if($c->[_OP_NAME] eq 'macro_begin') {
                    $macro = [];
                    $macro = {
                        name  => $c->[_OP_ARG],
                        line  => $c->[_OP_LINE],
                        file  => $c->[_OP_FILE],
                        body  => [],
                    };
                    push @{ $mtable->{$c->[_OP_ARG]} ||= [] }, $macro;
                }
                elsif($c->[_OP_NAME] eq 'macro_nargs') {
                    $macro->{nargs} = $c->[_OP_ARG];
                }
                elsif($c->[_OP_NAME] eq 'macro_outer') {
                    $macro->{outer} = $c->[_OP_ARG];
                }
                elsif($c->[_OP_NAME] eq 'macro_end') {
                    # noop
                }
                else {
                    push @{$macro->{body}}, $c;
                }
            }
            elsif($c->[_OP_NAME] eq 'depend') {
                $self->requires($c->[_OP_ARG]);
            }
        }
        $self->requires($fullpath);
        $self->_process_cascade_file($cfile, $base_code);
    }

    if(defined $base) { # pure cascade
        $self->_process_cascade_file($base_file, $base_code);
        if(defined $vars) {
            unshift @{$base_code}, $self->_localize_vars($vars);
        }

        foreach my $c(@{$main_code}) {
            if($c->[_OP_NAME] eq 'print_raw_s'
                    && $c->[_OP_ARG] =~ m{ [^ \t\r\n] }xms) {
                Carp::carp("Xslate: Useless use of text '$c->[1]'");
            }
        }
        @{$main_code} = @{$base_code};
    }
    else { # overlay
        return;
    }
}

sub _process_cascade_file {
    my($self, $file, $base_code) = @_;
    printf STDERR "# cascade file %s\n", p($file) if _DUMP_CAS;
    my $mtable = $self->macro_table;

    for(my $i = 0; $i < @{$base_code}; $i++) {
        my $c = $base_code->[$i];
        if($c->[_OP_NAME] ne 'macro_begin') {
            next;
        }

        # macro
        my $name = $c->[_OP_ARG];
        $name =~ s/\@.+$//;
        printf STDERR "# macro %s\n", $name if _DUMP_CAS;

        if(exists $mtable->{$name}) {
            my $m = $mtable->{$name};
            if(ref($m) ne 'HASH') {
                $self->_error('[BUG] Unexpected macro structure: '
                    . p($m) );
            }

            $self->_error(
                "Redefinition of macro/block $name in " . $file
                . " (you must use block modifiers to override macros/blocks)",
                $m->{line}
            );
        }

        my $before = delete $mtable->{$name . '@before'};
        my $around = delete $mtable->{$name . '@around'};
        my $after  = delete $mtable->{$name . '@after'};

        if(defined $before) {
            my $n = scalar @{$base_code};
            foreach my $m(@{$before}) {
                splice @{$base_code}, $i+1, 0, @{$m->{body}};
            }
            $i += scalar(@{$base_code}) - $n;
        }

        my $macro_start = $i+1;
        $i++ while($base_code->[$i][_OP_NAME] ne 'macro_end'); # move to the end

        if(defined $around) {
            my @original = splice @{$base_code}, $macro_start, ($i - $macro_start);
            $i = $macro_start;

            my @body;
            foreach my $m(@{$around}) {
                push @body, @{$m->{body}};
            }
            for(my $j = 0; $j < @body; $j++) {
                if($body[$j][_OP_NAME] eq 'super') {
                    splice @body, $j, 1, @original;
                }
            }
            splice @{$base_code}, $macro_start, 0, @body;

            $i += scalar(@body);
        }

        if(defined $after) {
            foreach my $m(@{$after}) {
                splice @{$base_code}, $i, 0, @{$m->{body}};
            }
        }
    }
    return;
}


sub _flush_macro_table {
    my($self) = @_;
    my $mtable = $self->macro_table;
    my @code;
    foreach my $macros(values %{$mtable}) {
        foreach my $macro(ref($macros) eq 'ARRAY' ? @{$macros} : $macros) {
            push @code,
                $self->opcode( macro_begin => $macro->{name},
                    file => $macro->{file},
                    line => $macro->{line} );

            push @code, $self->opcode( macro_nargs => $macro->{nargs} )
                if $macro->{nargs};

            push @code, $self->opcode( macro_outer => $macro->{outer} )
                if $macro->{outer};

            push @code, @{ $macro->{body} }, $self->opcode('macro_end');
        }
    }
    %{$mtable} = ();
    return @code;
}

sub _generate_name {
    my($self, $node) = @_;

    my $id = $node->value; # may be aliased
    if(defined(my $lvar_id = $self->lvar->{$id})) { # constants
        my $code = $self->const->[$lvar_id];
        if(defined $code) {
            # because the constant value is very simple,
            # its definition is optimized away.
            # only its value remains.
            return @{$code};
        }
        else {
            return $self->opcode( load_lvar => $lvar_id, symbol => $node );
        }
    }

    return $self->opcode( fetch_symbol => $id, line => $node->line );
}

sub _generate_operator {
    my($self, $node) = @_;
    # This method is called when an operators is used as an expression,
    # e.g. <: + :>, so simply throws the error
    $self->_error("Invalid expression", $node);
}

sub _can_optimize_print {
    my($self, $name, $node) = @_;

    return 0 if !$OPTIMIZE;
    return 0 if !($name eq 'print' or $name eq 'print_raw');

    my $maybe_name = $node->first;
    return $node->arity eq 'call'
        && $maybe_name->arity eq 'name'
        && @{$node->second} == 1 # args of the filter
        && any_in($maybe_name->id, qw(raw mark_raw html))
        && !$self->overridden_builtin->{$maybe_name->id};
}

# also deal with smart escaping
sub _generate_print {
    my($self, $node) = @_;

    my @code;

    my $proc = $node->id;
    if($proc eq 'print' and $self->type eq 'text') {
        $proc = 'print_raw';
    }

    foreach my $arg(@{ $node->first }){
        if( $proc eq 'print' && $self->overridden_builtin->{html_escape} ) {
            # default behaviour of print() is overridden
            push @code,
                $self->opcode('pushmark'),
                $self->compile_ast($arg),
                $self->opcode('push'),
                $self->opcode('fetch_symbol' => 'html_escape'),
                $self->opcode('funcall'),
                $self->opcode('print_raw');
        }
        elsif(exists $Text::Xslate::OPS{$proc . '_s'}
                && $arg->arity eq 'literal'){
            push @code,
                $self->opcode( $proc . '_s' => $arg->value,
                               line         => $arg->line );
        }
        elsif($self->_can_optimize_print($proc, $arg)){
            my $filter      = $arg->first;
            my $filter_name = $filter->id;
            my $command = $builtin{ $filter_name }[0] eq 'builtin_mark_raw'
                ? 'print_raw'  # mark_raw, raw
                : 'print';     # html

            push @code,
                $self->compile_ast($arg->second->[0]),
                $self->opcode(
                    $command => undef,
                    symbol   => $filter );

        }
        else {
            push @code,
                $self->compile_ast($arg),
                $self->opcode( $proc => undef, line => $node->line );
        }
    }

    if(!@code) {
        $self->_error("$node requires at least one argument", $node);
    }
    return @code;
}

sub _generate_include {
    my($self, $node) = @_;

    my $file = $node->first;
    my @code = (
        ( ref($file) eq 'ARRAY'
            ? $self->opcode( literal => $self->_bare_to_file($file) )
            : $self->compile_ast($file) ),
        $self->opcode( $node->id => undef, line => $node->line ),
    );

    if(defined(my $vars = $node->second)) {
        @code = ($self->opcode('enter'),
            $self->_localize_vars($vars),
            @code,
            $self->opcode('leave'),
        );
    }
    return @code;
}

sub _bare_to_file {
    my($self, $file) = @_;
    if(ref($file) eq 'ARRAY') { # myapp::foo
        return join('/', map { $_->value } @{$file}) . $self->{engine}->{suffix};
    }
    elsif($file->arity eq 'literal') {
        return $file->value;
    }
    else {
        $self->_error("Expected a name or string literal", $file);
    }
}

sub _generate_cascade {
    my($self, $node) = @_;
    if(defined $self->cascade) {
        $self->_error("Cannot cascade twice in a template", $node);
    }
    $self->cascade( $node );
    return;
}

# XXX: need more consideration
sub _compile_loop_block {
    my($self, $block) = @_;
    my @block_code = $self->compile_ast($block);

    foreach my $op(@block_code) {
        if(any_in( $op->[_OP_NAME], qw(pushmark loop_control))) {
            # pushmark ... funcall (or something) may create mortal SVs
            # so surround the block with ENTER and LEAVE
            unshift @block_code, $self->opcode('enter');
            push    @block_code, $self->opcode('leave');
            last;
        }
    }

    foreach my $i(1 .. (@block_code-1)) {
        my $op = $block_code[$i];
        if($op->[_OP_NAME] eq 'loop_control') {
            my $type = $op->[_OP_ARG];
            $op->[_OP_NAME] = 'goto';

            $op->[_OP_ARG] = (@block_code - $i);

            $op->[_OP_ARG] += 1 if $type eq 'last';
        }
    }

    return @block_code;
}

sub _generate_for {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} != 1) {
        $self->_error("A for-loop requires single variable for each item", $node);
    }
    local $self->{lvar}  = { %{$self->lvar} };  # new scope
    local $self->{const} = [ @{$self->const} ]; # new scope
    local $self->{in_loop} = _FOR_LOOP;

    my @code = $self->compile_ast($expr);

    my($iter_var) = @{$vars};
    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $iter_var->id;

    $self->lvar->{$lvar_name} = $lvar_id;
    $self->lvar->{'($_)'}     = $lvar_id;

    push @code, $self->opcode( for_start => $lvar_id, symbol => $iter_var );

    # a for statement uses three local variables (container, iterator, and item)
    local $self->{lvar_id} = $self->lvar_use(3);

    my @block_code = $self->_compile_loop_block($block);
    push @code,
        $self->opcode( literal_i => $lvar_id, symbol => $iter_var ),
        $self->opcode( for_iter  => scalar(@block_code) + 2 ),
        @block_code,
        $self->opcode( goto      => -(scalar(@block_code) + 2), comment => "end for" );

    return @code;
}

sub _generate_for_else {
    my($self, $node) = @_;

    my $for_block  = $node->first;
    my $else_block = $node->second;

    my @code = (
        $self->compile_ast($for_block),
    );

    # 'for' block sets __a with true if the loop count > 0
    my @else = $self->compile_ast($else_block);
    push @code, (
        $self->opcode( or => scalar(@else) + 1, comment => 'for-else' ),
        @else,
    );

    return @code;
}

sub _generate_while {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} > 1) {
        $self->_error("A while-loop requires one or zero variable for each items", $node);
    }

    (my $cond_op, undef, $expr) = $self->_prepare_cond_expr($expr);

    # TODO: combine all the loop contexts into single one
    local $self->{lvar}  = { %{$self->lvar}  }; # new scope
    local $self->{const} = [ @{$self->const} ]; # new scope
    local $self->{in_loop} = _WHILE_LOOP;

    my @code = $self->compile_ast($expr);

    my($iter_var) = @{$vars};
    my($lvar_id, $lvar_name);

    if(@{$vars}) {
        $lvar_id                  = $self->lvar_id;
        $lvar_name                = $iter_var->id;
        $self->lvar->{$lvar_name} = $lvar_id;
        push @code, $self->opcode( save_to_lvar => $lvar_id, symbol => $iter_var );
    }

    local $self->{lvar_id} = $self->lvar_use(scalar @{$vars});
    my @block_code = $self->_compile_loop_block($block);
    return @code,
        $self->opcode( $cond_op => scalar(@block_code) + 2, symbol => $node ),
        @block_code,
        $self->opcode( goto => -(scalar(@block_code) + scalar(@code) + 1), comment => "end while" );

    return @code;
}

sub _generate_loop_control {
    my($self, $node) = @_;
    my $type = $node->id;

    any_in($type, qw(last next))
        or $self->_error("[BUG] Unknown loop control statement '$type'");

    if(not $self->{in_loop}) {
        $self->_error("Use of loop control statement ($type) outside of loops");
    }

    my @cleanup;
    if( $self->{in_loop} == _FOR_LOOP && $type eq 'last' ) {
        my $lvar_id = $self->lvar->{'($_)'};
        defined($lvar_id)
            or $self->_error('[BUG] Undefined loop iterator');

        @cleanup = (
            $self->opcode( 'nil', undef,
                comment => 'to clean the loop context' ),
            $self->opcode( save_to_lvar => $lvar_id + 0), # item
            $self->opcode( save_to_lvar => $lvar_id + 1), # iterator
            $self->opcode( save_to_lvar => $lvar_id + 2), # body
            $self->opcode( literal_i    => 1 ), # for 'for-else'
        );
    }

    return $self->opcode('leave'),
           @cleanup,
           $self->opcode('loop_control' => $type, comment => $type);
}

sub _generate_proc { # definition of macro, block, before, around, after
    my($self, $node) = @_;
    my $type   = $node->id;
    my $name   = $node->first->id;
    my @args   = map{ $_->id } @{$node->second};
    my $block  = $node->third;

    local $self->{lvar}  = { %{$self->lvar}  }; # new scope
    local $self->{const} = [ @{$self->const} ]; # new scope

    my $lvar_used = $self->lvar_id;
    my $arg_ix    = 0;
    foreach my $arg(@args) {
        # to fetch ST(ix)
        # Note that arg_ix must be start from 1
        $self->lvar->{$arg} = $lvar_used + $arg_ix++;
    }

    local $self->{lvar_id} = $self->lvar_use($arg_ix);

    my $opinfo = $self->opcode(set_opinfo => undef, file => $self->filename, line => $node->line);
    my %macro = (
        name      => $name,
        nargs     => $arg_ix,
        body      => [ $opinfo, $self->compile_ast($block) ],
        line      => $opinfo->[2],
        file      => $opinfo->[3],
        outer     => $lvar_used,
    );

    if(any_in($type, qw(macro block))) {
        if(exists $self->macro_table->{$name}) {
            my $m = $self->macro_table->{$name};
            if(p(\%macro) ne p($m)) {
                $self->_error("Redefinition of $type $name is forbidden", $node);
            }
        }
        $self->macro_table->{$name} = \%macro;
    }
    else {
        my $fq_name = sprintf '%s@%s', $name, $type;
        $macro{name} = $fq_name;
        push @{ $self->macro_table->{ $fq_name } ||= [] }, \%macro;
    }
    return;
}

sub _generate_lambda {
    my($self, $node) = @_;

    my $macro = $node->first;
    $self->compile_ast($macro);
    return $self->opcode( fetch_symbol => $macro->first->id, line => $node->line );
}

sub _prepare_cond_expr {
    my($self, $expr) = @_;
    my $t = "and";
    my $f = "or";

    while($expr->id eq '!') {
        $expr    = $expr->first;
        ($t, $f) = ($f, $t);
    }

    if($expr->is_logical and any_in($expr->id, qw(== !=))) {
        my $rhs = $expr->second;
        if($rhs->arity eq "nil") {
            # add prefix 'd' (i.e. "and" to "dand", "or" to "dor")
            substr $t, 0, 0, 'd';
            substr $f, 0, 0, 'd';

            if($expr->id eq "==") {
                ($t, $f) = ($f, $t);
            }
            $expr = $expr->first;
        }
    }

    return($t, $f, $expr);
}

sub _generate_if {
    my($self, $node) = @_;
    my $first  = $node->first;
    my $second = $node->second;
    my $third  = $node->third;

    my($cond_true, $cond_false, $expr) = $self->_prepare_cond_expr($first);

    local $self->{lvar}  = { %{$self->lvar}  }; # new scope
    local $self->{const} = [ @{$self->const} ]; # new scope
    my @cond  = $self->compile_ast($expr);

    my @then = do {
        local $self->{lvar}  = { %{$self->lvar}  }; # new scope
        local $self->{const} = [ @{$self->const} ]; # new scope
        $self->compile_ast($second);
    };

    my @else = do {
        local $self->{lvar}  = { %{$self->lvar}  }; # new scope
        local $self->{const} = [ @{$self->const} ]; # new scope
        $self->compile_ast($third);
    };

    if($OPTIMIZE) {
        if($self->_code_is_literal(@cond)) {
            my $value = $cond[0][_OP_ARG];
            if($cond_true eq 'and' ? $value : !$value) {
                return @then;
            }
            else {
                return @else;
            }
        }
    }

    if( (@then and @else) or !$OPTIMIZE) {
        return(
            @cond,
            $self->opcode( $cond_true => scalar(@then) + 2, comment => $node->id . ' (then)' ),
            @then,
            $self->opcode( goto => scalar(@else) + 1, comment => $node->id . ' (else)' ),
            @else,
        );
    }
    elsif(!@else) { # no @else
        return(
            @cond,
            $self->opcode( $cond_true => scalar(@then) + 1, comment => $node->id . ' (then/no-else)' ),
            @then,
        );
    }
    else { # no @then
        return(
            @cond,
            $self->opcode( $cond_false => scalar(@else) + 1, comment => $node->id . ' (else/no-then)'),
            @else,
        );
    }
}

sub _generate_given {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} > 1) {
        $self->_error("A given block requires one or zero variables", $node);
    }
    local $self->{lvar}  = { %{$self->lvar}  }; # new scope
    local $self->{const} = [ @{$self->const} ]; # new scope

    my @code = $self->compile_ast($expr);

    my($lvar)     = @{$vars};
    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $lvar->id;

    $self->lvar->{$lvar_name} = $lvar_id;

    local $self->{lvar_id} = $self->lvar_use(1); # topic variable
    push @code, $self->opcode( save_to_lvar => $lvar_id, symbol => $lvar ),
        $self->compile_ast($block);

    return @code;
}

sub _generate_variable {
    my($self, $node) = @_;

    if(defined(my $lvar_id = $self->lvar->{$node->value})) {
        return $self->opcode( load_lvar => $lvar_id, symbol => $node );
    }
    else {
        my $name = $self->_variable_to_value($node);
        if($name =~ /~/) {
            $self->_error("Undefined iterator variable $node", $node);
        }
        return $self->opcode( fetch_s => $name, line => $node->line );
    }
}

sub _generate_super {
    my($self, $node) = @_;

    return return $self->opcode( super => undef, symbol => $node );
}

sub _generate_literal {
    my($self, $node) = @_;
    return $self->opcode( literal => $node->value );
}

sub _generate_nil {
    my($self) = @_;
    return $self->opcode('nil');
}

sub _generate_vars {
    my($self) = @_;
    return $self->opcode('vars');
}

sub _generate_composer {
    my($self, $node) = @_;

    my $list = $node->first;
    my $type = $node->id eq '{' ? 'make_hash' : 'make_array';

    return
        $self->opcode( pushmark => undef, comment => $type ),
        (map{ $self->push_expr($_) } @{$list}),
        $self->opcode($type),
    ;
}

sub _generate_unary {
    my($self, $node) = @_;

    my $id = $node->id;
    if(exists $unary{$id}) {
        my @operand = $self->compile_ast($node->first);
        my @code = (
            @operand,
            $self->opcode( $unary{$id} )
        );
        if( $OPTIMIZE and $self->_code_is_literal(@operand) ) {
            $self->_fold_constants(\@code);
        }
        return @code;
    }
    else {
        $self->_error("Unary operator $id is not implemented", $node);
    }
}

sub _generate_field {
    my($self, $node) = @_;

    my @lhs   = $self->compile_ast($node->first);
    my $field = $node->second;

    # $foo.field
    # $foo["field"]
    if($field->arity eq "literal") {
        return
            @lhs,
            $self->opcode( fetch_field_s => $field->value );
    }
    # $foo[expression]
    else {
        local $self->{lvar_id} = $self->lvar_use(1);
        my @rhs = $self->compile_ast($field);
        if($OPTIMIZE and $self->_code_is_literal(@rhs)) {
            return
                @lhs,
                $self->opcode( fetch_field_s => $rhs[0][1] );
        }
        return
            @lhs,
            $self->opcode( save_to_lvar => $self->lvar_id ),
            @rhs,
            $self->opcode( load_lvar_to_sb => $self->lvar_id ),
            $self->opcode( 'fetch_field' ),
        ;
    }

}

sub _generate_binary {
    my($self, $node) = @_;

    my @lhs = $self->compile_ast($node->first);

    my $id = $node->id;
    if(exists $binary{$id}) {
        local $self->{lvar_id} = $self->lvar_use(1);
        my @rhs = $self->compile_ast($node->second);
        my @code = (
            @lhs,
            $self->opcode( save_to_lvar => $self->lvar_id ),
            @rhs,
            $self->opcode( load_lvar_to_sb => $self->lvar_id ),
            $self->opcode( $binary{$id} ),
        );

        if(any_in($id, qw(min max))) {
            local $self->{lvar_id} = $self->lvar_use(1);
            splice @code, -1, 0,
                $self->opcode(save_to_lvar => $self->lvar_id ); # save lhs
            push @code,
                $self->opcode( or => +2 , symbol => $node ),
                $self->opcode( load_lvar_to_sb => $self->lvar_id ), # on true
                # fall through
                $self->opcode( 'move_from_sb' ), # on false
        }

        if($OPTIMIZE) {
            if( $self->_code_is_literal(@lhs) and $self->_code_is_literal(@rhs) ){
                $self->_fold_constants(\@code);
            }
        }
        return @code;
    }
    elsif(exists $logical_binary{$id}) {
        my @rhs = $self->compile_ast($node->second);
        return
            @lhs,
            $self->opcode( $logical_binary{$id} => scalar(@rhs) + 1, symbol => $node ),
            @rhs;
    }

    $self->_error("Binary operator $id is not implemented", $node);
}

sub _generate_range {
    my($self, $node) = @_;

    $self->can_be_in_list_context
        or $self->_error("Range operator must be in list context");

    my @lhs  = $self->compile_ast($node->first);

    local $self->{lvar_id} = $self->lvar_use(1);
    my @rhs = $self->compile_ast($node->second);
    return(
        @lhs,
        $self->opcode( save_to_lvar => $self->lvar_id ),
        @rhs,
        $self->opcode( load_lvar_to_sb => $self->lvar_id ),
        $self->opcode( 'range' ),
    );
}

sub _generate_methodcall {
    my($self, $node) = @_;

    my $args   = $node->third;
    my $method = $node->second->value;
    return (
        $self->opcode( pushmark => undef, comment => $method ),
        $self->push_expr($node->first),
        (map { $self->push_expr($_) } @{$args}),
        $self->opcode( methodcall_s => $method, line => $node->line ),
    );
}

sub _generate_call {
    my($self, $node) = @_;
    my $callable = $node->first; # function or macro
    my $args     = $node->second;

    if(my $intern = $builtin{$callable->id} and !$self->overridden_builtin->{$callable->id}) {
        if(@{$args} != 1) {
            $self->_error("Wrong number of arguments for $callable", $node);
        }

        return $self->compile_ast($args->[0]),
            [ $intern->[0] => undef, $node->line ];
    }

    return(
        $self->opcode( pushmark => undef, comment => $callable->id ),
        (map { $self->push_expr($_) } @{$args}),
        $self->compile_ast($callable),
        $self->opcode( 'funcall' )
    );
}

# $~iterator
sub _generate_iterator {
    my($self, $node) = @_;

    my $item_var = $node->first;
    my $lvar_id  = $self->lvar->{$item_var};
    if(!defined($lvar_id)) {
        $self->_error("Refer to iterator $node, but $item_var is not defined",
            $node);
    }

    return $self->opcode(
        load_lvar => $lvar_id + 1,
        symbol    => $node,
    );
}

# $~iterator.body
sub _generate_iterator_body {
    my($self, $node) = @_;

    my $item_var = $node->first;
    my $lvar_id  = $self->lvar->{$item_var};
    if(!defined($lvar_id)) {
        $self->_error("Refer to iterator $node.body, but $item_var is not defined",
            $node);
    }

    return $self->opcode(
        load_lvar => $lvar_id + 2,
        symbol    => $node,
    );
}

sub _generate_assign {
    my($self, $node) = @_;
    my $lhs     = $node->first;
    my $rhs     = $node->second;
    my $is_decl = $node->third;

    my $lvar      = $self->lvar;
    my $lvar_name = $lhs->id;

    if($node->id ne "=") {
        $self->_error("Assignment ($node) is not supported", $node);
    }

    my @expr = $self->compile_ast($rhs);

    if($is_decl) {
        $lvar->{$lvar_name} = $self->lvar_id;
        $self->{lvar_id}    = $self->lvar_use(1); # don't use local()
    }

    if(!exists $lvar->{$lvar_name} or $lhs->arity ne "variable") {
        $self->_error("Cannot modify $lhs, which is not a lexical variable", $node);
    }

    return
        @expr,
        $self->opcode( save_to_lvar => $lvar->{$lvar_name}, symbol => $lhs, comment => $node->id);
}

sub _generate_constant {
    my($self, $node) = @_;
    my $lhs     = $node->first;
    my $rhs     = $node->second;

    my @expr = $self->compile_ast($rhs);

    my $lvar            = $self->lvar;
    my $lvar_id         = $self->lvar_id;
    my $lvar_name       = $lhs->id;
    $lvar->{$lvar_name} = $lvar_id;
    $self->{lvar_id}    = $self->lvar_use(1); # don't use local()

    if($OPTIMIZE) {
        if(@expr == 1
                && any_in($expr[0][_OP_NAME], qw(literal load_lvar))) {
            $expr[0][_OP_COMMENT] = "constant $lvar_name";
            $self->const->[$lvar_id] = \@expr;
            return @expr; # no real definition
        }
    }

    return
        @expr,
        $self->opcode( save_to_lvar => $lvar_id, symbol => $lhs, comment => $node->id);
}

sub _localize_vars {
    my($self, $vars) = @_;
    my @localize;
    my @pairs = @{$vars};

    if( (@pairs % 2) != 0 ) {
        if(@pairs == 1) {
            return $self->compile_ast(@pairs),
                $self->opcode( 'localize_vars' );
        }
        else {
            $self->_error("You must pass pairs of expressions to include");
        }
    }

    while(my($key, $expr) = splice @pairs, 0, 2) {
        if(!any_in($key->arity, qw(literal variable))) {
            $self->_error("You must pass a simple name to localize variables", $key);
        }
        push @localize,
            $self->compile_ast($expr),
            $self->opcode( localize_s => $key->value, symbol => $key );
    }
    return @localize;
}

sub _variable_to_value {
    my($self, $arg) = @_;

    my $name = $arg->value;
    $name =~ s/\$//;
    return $name;
}

sub requires {
    my($self, @files) = @_;
    push @{ $self->dependencies }, @files;
    return;
}

sub can_be_in_list_context {
    my $i = 2;
    while(my $funcname = (caller ++$i)[3]) {
        if($funcname =~ /::_generate_(\w+) \z/xms) {
            return any_in($1,  qw(
                methodcall
                call
                composer
            ));
        }
    }
    return 0;
}

# optimizatin stuff

sub _code_is_literal {
    my($self, @code) = @_;
    return @code == 1
        && (    $code[0][_OP_NAME] eq 'literal'
             || $code[0][_OP_NAME] eq 'literal_i');
}

sub _fold_constants {
    my($self, $code) = @_;
    my $engine = $self->engine or return 0;

    local $engine->{warn_handler} = \&Carp::croak;
    local $engine->{die_handler}  = \&Carp::croak;
    local $engine->{verbose}      = 1;

    my $result = eval {
        my @tmp_code = (@{$code}, $self->opcode('print_raw'), $self->opcode('end'));
        $engine->_assemble(\@tmp_code, '<string>', undef, undef, undef);
        $engine->render('<string>');
    };
    if($@) {
        Carp::carp("[BUG] Constant folding failed (ignored): $@");
        return 0;
    }

    @{$code} = ($self->opcode( literal => $result, comment => "optimized by constant folding"));
    return 1;
}


sub _noop {
    my($self, $op) = @_;
    @{$op} = @{ $self->opcode( noop => undef, comment => "ex-$op->[0]") };
    return;
}

sub _optimize_vmcode {
    my($self, $c) = @_;

    # calculate goto addresses
    # eg:
    #
    # goto +3
    # foo
    # noop
    # bar // goto destination
    #
    # to be:
    #
    # goto +2
    # foo
    # bar // goto destination

    my @goto_addr;
    for(my $i = 0; $i < @{$c}; $i++) {
        if(exists $goto_family{ $c->[$i][_OP_NAME] }) {
            my $addr = $c->[$i][_OP_ARG]; # relational addr

            # mark ragens that goto family have its effects
            my @range = $addr > 0
                ? ($i .. ($i+$addr-1))  # positive
                : (($i+$addr) .. $i); # negative

            foreach my $j(@range) {
                push @{$goto_addr[$j] ||= []}, $c->[$i];
            }
        }
    }

    for(my $i = 0; $i < @{$c}; $i++) {
        my $name = $c->[$i][_OP_NAME];
        if($name eq 'print_raw_s') {
            # merge a chain of print_raw_s into single command
            my $j = $i + 1; # from the next op
            while($j < @{$c}
                    && $c->[$j][_OP_NAME] eq 'print_raw_s'
                    && "@{$goto_addr[$i] || []}" eq "@{$goto_addr[$j] || []}") {

                $c->[$i][_OP_ARG] .= $c->[$j][_OP_ARG];

                $self->_noop($c->[$j]);
                $j++;
            }
        }
        elsif($name eq 'save_to_lvar') {
            # use registers, instead of local variables
            #
            # given:
            #   save_to_lvar $n
            #   <single-op>
            #   load_lvar_to_sb $n
            # convert into:
            #   move_to_sb
            #   <single-op>
            my $it = $c->[$i];
            my $nn = $c->[$i+2]; # next next
            if(defined($nn)
                && $nn->[_OP_NAME] eq 'load_lvar_to_sb'
                && $nn->[_OP_ARG] == $it->[_OP_ARG]) {
                @{$it} = @{$self->opcode( move_to_sb => undef, comment => "ex-$it->[0]" )};

                $self->_noop($nn);
            }
        }
        elsif($name eq 'literal') {
            if(is_int($c->[$i][_OP_ARG])) {
                $c->[$i][_OP_NAME] = 'literal_i';
                $c->[$i][_OP_ARG]  = int($c->[$i][_OP_ARG]); # force int
            }
        }
        elsif($name eq 'fetch_field') {
            my $prev = $c->[$i-1];
            if($prev->[_OP_NAME] =~ /^literal/) { # literal or literal_i
                $c->[$i][_OP_NAME] = 'fetch_field_s';
                $c->[$i][_OP_ARG] = $prev->[_OP_ARG]; # arg

                $self->_noop($prev);
            }
        }
    }

    # remove noop
    for(my $i = 0; $i < @{$c}; $i++) {
        if($c->[$i][_OP_NAME] eq 'noop') {
            if(defined $goto_addr[$i]) {
                foreach my $goto(@{ $goto_addr[$i] }) {
                    # reduce its absolute value
                    $goto->[1] > 0
                        ? $goto->[1]--  # positive
                        : $goto->[1]++; # negative
                }
            }
            splice @{$c}, $i, 1;
            # adjust @goto_addr, but it may be empty
            splice @goto_addr, $i, 1 if @goto_addr > $i;
        }
    }
    return;
}

sub as_assembly {
    my($self, $code_ref, $addix) = @_;

    my $asm = "";
    foreach my $ix(0 .. (@{$code_ref}-1)) {
        my($name, $arg, $line, $file, $label, $comment) = @{$code_ref->[$ix]};
        $asm .= "$ix:" if $addix; # for debugging

        # "$opname $arg #$line:$file *$symbol // $comment"
        ref($name) and die "Oops: " . p($code_ref->[$ix]);
        $asm .= $name;
        if(defined $arg) {
            $asm .= " " . value_to_literal($arg);
        }
        if(defined $line) {
            $asm .= " #$line";
            if(defined $file) {
                $asm .= ":" . value_to_literal($file);
            }
        }
        if(defined $label) {
            $asm .= " " . value_to_literal($label);
        }
        if(defined $comment) {
            $asm .= " // $comment";
        }
        $asm .= "\n";
    }
    return $asm;
}

sub _error {
    my($self, $message, $node) = @_;

    my $line = ref($node) ? $node->line : $node;
    die $self->make_error($message, $self->file, $line);
}

no Mouse;
no Mouse::Util::TypeConstraints;

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::Compiler - An Xslate compiler to generate intermediate code

=head1 DESCRIPTION

This is the Xslate compiler to generate the intermediate code from the
abstract syntax tree that parsers build from templates.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::Parser>

L<Text::Xslate::Symbol>

=cut
