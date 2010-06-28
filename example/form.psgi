#!perl -w
use strict;
use Text::Xslate;
use HTML::Shakan;
use Plack::Request;

my $tx  = Text::Xslate->new(
    verbose      => 2,
    warn_handler => \&Carp::croak,
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

sub app {
    my($env) = @_;
    my $req  = Plack::Request->new($env);

    my $form = My::Form->get( add => ( request => $req) );

    my @errors;
    if($form->has_error) {
        $form->load_function_message('en');
        @errors = $form->get_error_messages();
    }

    my $res = $req->new_response(200);

    $res->body( $tx->render_string(<<'T', { form => $form, errors => \@errors }) );
<!doctype html>
<html>
<head><title>Using Form Builder</title></head>
<body>
<form>
<p>
Form:<br />
: $form.render() | raw
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

    return $res->finalize();

}

return \&app;
