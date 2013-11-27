#!perl

requires 'perl', '5.008001';
requires 'Data::MessagePack', '0.38';
requires 'Mouse', '0.61';
requires 'Scalar::Util', '1.14';
requires 'XSLoader', '0.02';
requires 'parent', '0.221';
feature 'Scope::Guard', 0; # for logging

on configure => sub {
    requires 'Devel::PPPort', '3.19';
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'ExtUtils::ParseXS', '3.21';
    requires 'File::Copy::Recursive';
    requires 'Module::Build::XSUtil';
};

on test => sub {
    requires 'Test::More', '0.88';
    requires 'Test::Requires';
};

