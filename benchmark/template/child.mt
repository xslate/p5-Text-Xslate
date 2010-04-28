? extends "base"

<? block title => sub { ?>My amazing blog<? }; ?>

? block content => sub {
? for my $entry(@$blog_entries) {
    <h2><?= $entry->title ?></h2>
    <p><?= $entry->body ?></p>
? }
? };
