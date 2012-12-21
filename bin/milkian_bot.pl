#!perl
use strict;
use warnings;
use utf8;
use App::Daemon qw(daemonize);
use App::MilkianBot;

binmode STDOUT, ":utf8";

daemonize();

my $bot = App::MilkianBot->new();
$bot->run;


