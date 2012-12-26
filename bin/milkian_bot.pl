#!perl
use strict;
use warnings;
use utf8;
use App::Daemon qw(daemonize);
use FindBin;
use lib "$FindBin::RealBin/../lib";
use App::MilkianBot;

binmode STDOUT, ":utf8";

daemonize();

my $bot = App::MilkianBot->new();
$bot->run;


