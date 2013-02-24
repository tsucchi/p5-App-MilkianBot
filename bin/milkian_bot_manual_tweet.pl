#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Encode;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use App::MilkianBot;

binmode STDOUT, ":utf8";
my $tweet = decode_utf8($ARGV[0]);

die "no message" if ( !defined $tweet );

my $bot = App::MilkianBot->new();
$bot->simple_tweet($tweet);

