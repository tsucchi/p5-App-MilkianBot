#!/usr/bin/perl
use strict;
use warnings;
use Config::Pit;
use AnyEvent::Twitter;
use utf8;
use Encode;

binmode STDOUT, ":utf8";
my $tweet = decode_utf8($ARGV[0]);

die "no message" if ( !defined $tweet );

my $config = pit_get("milkian_bot", require => {
    consumer_key    => 'consumer_key',
    consumer_secret => 'consumer_secret',
    token           => 'token',
    token_secret    => 'token_secret',
});

my $done = AnyEvent->condvar;
my $twitty = AnyEvent::Twitter->new(
    username        => 'milkian_bot',
    consumer_key    => $config->{consumer_key},
    consumer_secret => $config->{consumer_secret},
    token           => $config->{token},
    token_secret    => $config->{token_secret},
);
$done->begin;
$twitty->post('statuses/update', {
    status => $tweet,
}, sub {
    my ($header, $response, $reason) = @_;
    $done->end;
});


$done->recv;
