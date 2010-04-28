<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <link rel="stylesheet" href="style.css" />
    <title><? block title => sub { ?>My amazing site<? }; ?></title>
</head>

<body>
    <div id="sidebar">
        <? block sidebar => sub { ?>
        <ul>
            <li><a href="/">Home</a></li>
            <li><a href="/blog/">Blog</a></li>
        </ul>
        <? } ?>
    </div>

    <div id="content">
        <? block content => sub { } ?>
    </div>
</body>
</html>
