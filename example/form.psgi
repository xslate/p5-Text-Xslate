#!perl -w
use strict;
use Text::Xslate qw(mark_raw);
use HTML::Shakan 0.05;
use Plack::Request;

my %vpath = (
    'form.tx' => <<'T',
<!doctype html>
<html>
<head><title>Using Form Builder</title></head>
<body>
<form>
<p>
Form:<br />
<: $form :>
<input type="submit" />
</p>
: if $errors.size() > 0 {
<p class="error">
Errors (<: $errors.size() :>):<br />
: for $errors -> $e {
    <: $e :><br />
: }
</p>
: }
</form>
</body>
</html>
T
);

my $tx  = Text::Xslate->new(
    path         => \%vpath,
    verbose      => 2,
    warn_handler => \&Carp::croak,
    cache        => 0,
);

{
    package My::Form;
    use HTML::Shakan::Declare;

    form 'add' => (
        TextField(
            name     => 'name',
            label    => 'name: ',
            required => 1,
        ),
        EmailField(
            name     => 'email',
            label    => 'email: ',
            required => 1,
        ),
    );
}

return sub {
    my($env) = @_;
    my $req  = Plack::Request->new($env);

    my $shakan = My::Form->get( add => ( request => $req) );

    my @errors;
    if($shakan->has_error) {
        $shakan->load_function_message('en');
        @errors = $shakan->get_error_messages();
    }

    my $res = $req->new_response(
        200,
        [ content_type => 'text/html; charset=utf8' ],
    );

    my $form = mark_raw( $shakan->render() );
    my $body = $tx->render('form.tx', { form => $form, errors => \@errors });
    utf8::encode($body);
    $res->body( $body );
    return $res->finalize();

};


