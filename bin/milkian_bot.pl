#!perl
use strict;
use warnings;
use Config::Pit;
use AnyEvent::Twitter;
use Net::SSLeay; # for AnyEvent::Twitter::Stream
use AnyEvent::Twitter::Stream;
use utf8;
use List::MoreUtils qw(any);
use App::Daemon qw(daemonize);

binmode STDOUT, ":utf8";

daemonize();

my @following_ids = (
    '114700374', #'mimori_suzuko',
    '261196483', #'tokui_sorangley',
    '244788445', #'mikoiwate_351',
    '161910608', #'izugyoza',
    '94825321',  #'milkyholmes',
);
my $my_id = '962596830'; #milkian_bot

my %keyword_for_mention = (
    qr/TMTOWTDI/                             => '正解はひとつ！じゃない！！',
    qr/There's more than one way to do it/   => '正解はひとつ！じゃない！！',
    qr/(俺|オレ)のタンメンまだ(ー|〜)?(\?|？)/ => 'まだですぅー',
);

my $config = pit_get("milkian_bot", require => {
    consumer_key    => 'consumer_key',
    consumer_secret => 'consumer_secret',
    token           => 'token',
    token_secret    => 'token_secret',
});

my %cred = (
    username        => 'milkian_bot',
    consumer_key    => $config->{consumer_key},
    consumer_secret => $config->{consumer_secret},
    token           => $config->{token},
    token_secret    => $config->{token_secret},
);

my $done = AnyEvent->condvar;

my $twitty = AnyEvent::Twitter->new(
    %cred,
);

my $listener = AnyEvent::Twitter::Stream->new(
    %cred,
    method   => 'filter',
    follow   => join(',', (@following_ids, $my_id)),
    on_tweet => sub {
        my $tweet = shift;
        my $user = $tweet->{user}->{screen_name};
        my $text = ($tweet->{text} || '');

        return unless $user && $text;

        if( any { $_ eq $tweet->{user}->{id} } @following_ids ) {
            print "$user : $text\n";
            my $message_id = $tweet->{id};
            $twitty->post("statuses/retweet/$message_id", {
            }, sub {
                my ($header, $response, $reason) = @_;
                print "retweeted\n";
            });
        }
        if( defined $tweet->{in_reply_to_user_id} && $tweet->{in_reply_to_user_id} eq $my_id ) {
            for my $keyword ( keys %keyword_for_mention ) {
                my $message = $keyword_for_mention{$keyword};
                if( $text =~ $keyword ) {
                    $twitty->post("statuses/update", {
                        status                => "\@$user $message",
                        in_reply_to_status_id => $tweet->{id},
                    }, sub {
                        my ($header, $response, $reason) = @_;
                        print "\@$user $message\n";
                    });
                }
            }
        }
    },
    on_error => sub {
        my $error = shift;
        warn "ERROR: $error";
        $done->send;
    },
    on_eof   => sub {
        $done->send;
    },
);

$done->recv;

