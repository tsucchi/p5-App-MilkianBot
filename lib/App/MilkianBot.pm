package App::MilkianBot;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite (
    ro => ['my_id', '_cred', '_following_ids', 'twitty', '_mention_for', 'is_background'],
);

use AnyEvent::Twitter;
use Config::Pit;
use Net::SSLeay; # for AnyEvent::Twitter::Stream
use AnyEvent::Twitter::Stream;
use List::MoreUtils qw(any);
use Encode;
use File::Stamped;
use Log::Minimal;
use FindBin;
use File::Basename;
use Time::Piece;

our $VERSION = '0.02';

sub new {
    my ($class, $option_href) = @_;
    my $is_background = defined $option_href->{background} ? $option_href->{background} : 0;
    my $self = {
        my_id => '962596830', #milkian_bot
        _following_ids => [
            '114700374', #'mimori_suzuko',
            '261196483', #'tokui_sorangley',
            '244788445', #'mikoiwate_351',
            '161910608', #'izugyoza',
            '94825321',  #'milkyholmes',
            '349409029', #'sorapiyo_bot',
        ],
        _mention_for => {
            qr/TMTOWTDI/                             => '正解はひとつ！じゃない！！',
            qr/There's more than one way to do it/   => '正解はひとつ！じゃない！！',
            qr/(俺|オレ)のタンメンまだ(ー|〜)?(\?|？)/ => 'まだですぅー',
        },
        is_background => $is_background,
    };
    bless $self, $class;
    $self->_init_credential();
    $self->{twitty} = AnyEvent::Twitter->new($self->credential);
    return $self;
}

sub _init_credential {
    my ($self) = @_;
    my $config = pit_get("milkian_bot", require => {
        consumer_key    => 'consumer_key',
        consumer_secret => 'consumer_secret',
        token           => 'token',
        token_secret    => 'token_secret',
    });

    $self->{_cred} = {
        username        => 'milkian_bot',
        consumer_key    => $config->{consumer_key},
        consumer_secret => $config->{consumer_secret},
        token           => $config->{token},
        token_secret    => $config->{token_secret},
    };
}

sub credential {
    my ($self) = @_;
    return %{ $self->_cred };
}

sub following_ids {
    my ($self) = @_;
    return @{ $self->_following_ids };
}

sub mention_for {
    my ($self) = @_;
    return %{ $self->_mention_for };
}

# 単発の tweet を投げます
sub simple_tweet {
    my ($self, $tweet) = @_;

    my $cv = AnyEvent->condvar;
    $cv->begin;
    $self->twitty->post('statuses/update', {
        status => $tweet,
    }, sub {
        my ($header, $response, $reason) = @_;
        $cv->end;
    });
    $cv->recv;
}

# bot として実行します。
sub run {
    my ($self) = @_;

    $self->logging('start', 'warn');

    my $cv = AnyEvent->condvar;
    my $good_morning_timer = $self->good_morning_timer();
    my $listener = AnyEvent::Twitter::Stream->new(
        $self->credential,
        method   => 'filter',
        follow   => join(',', ($self->following_ids, $self->my_id)),
        on_tweet => sub {
            my $tweet = shift;
            my $user = $tweet->{user}->{screen_name};
            my $text = ($tweet->{text} || '');

            return unless $user && $text;

            if ( $self->_is_nakano_hito_s_tweet($tweet) ) {
                $self->do_rt($tweet->{id}, $user, $text);
            }
            if ( $self->_is_mention_to_me($tweet) ) {
                $self->reply_to_mention_using_keyword($tweet->{id}, $user, $text);
            }
        },
        on_error => sub {
            my $error = shift;
            $self->logging("ERROR: " . decode_utf8($error), 'warn');
            $cv->send;
        },
        on_eof   => sub {
            $self->logging("EOF", 'warn');
            $cv->send;
        },
    );
    $cv->recv;
}

# 公式 RT を投げる
sub do_rt {
    my ($self, $id, $user, $text) = @_;
    $self->twitty->post("statuses/retweet/$id", {
    }, sub {
        my ($header, $response, $reason) = @_;
        $self->logging("retweeted: $user : $text\n");
    });
}

# おはよーおはよーを実行するタイマーを返す
sub good_morning_timer {
    my ($self) = @_;

    return AnyEvent->timer(
        after    => 0,
        interval => 300,
        cb       => sub {
            my $now = Time::Piece->new(AnyEvent->time);
            my $ymd = $now->ymd;
            my $format = "%Y-%m-%d %H:%M:%S";
            my $begin = localtime(Time::Piece->strptime("$ymd 07:00:00", $format));

            my $end   = $begin + 600; # 10 min after

            return if ( $self->{greeted}->{$ymd} );#あいさつ済みならこれ以上しない

            if( $begin < $now && $now < $end ) {
                $self->twitty->post('statuses/update', {
                    status => 'おはよーおはよー',
                }, sub {
                    my ($header, $response, $reason) = @_;
                });
                #print "おはよーおはよー\n";
                $self->{greeted}->{$ymd} = 1;#今日の挨拶は完了
            }
        },
    );
}


# メンションに対して特定のキーワードが含まれている場合に reply を返す
# 例) 「俺のタンメンまだー？」 => 「まだですぅー」
sub reply_to_mention_using_keyword {
    my ($self, $id, $user, $text) = @_;
    $self->logging("$user : $text\n");
    my %mention_for = $self->mention_for;
    for my $keyword ( keys %mention_for ) {
        my $message = $mention_for{$keyword};
        if ( $text =~ $keyword ) {
            my $reply_message = "\@$user $message";
            $self->twitty->post("statuses/update", {
                status                => $reply_message,
                in_reply_to_status_id => $id,
            }, sub {
                my ($header, $response, $reason) = @_;
                $self->logging("$reply_message\n");
            });
        }
    }
}

# 中の人の tweet かどうか
sub _is_nakano_hito_s_tweet {
    my ($self, $tweet) = @_;
    return any { $_ eq $tweet->{user}->{id} } $self->following_ids;
}

# milkian_bot へのメンションかどうか
sub _is_mention_to_me {
    my ($self, $tweet) = @_;
    return defined $tweet->{in_reply_to_user_id} && $tweet->{in_reply_to_user_id} eq $self->my_id;
}

sub logging {
    my ($self, $message, $severity) = @_;

    my $fh = File::Stamped->new(pattern => "$FindBin::RealBin/../milkian_bot.%Y%m%d.log");
    local $Log::Minimal::PRINT = sub {
        my ($time, $type, $message, $trace) = @_;
        my $app = basename($0);
        my $encoded_message = encode_utf8("$time [$app:$$] $type $message at $trace\n");
        if( $self->is_background ) {
            print {$fh} $encoded_message;
        }
        else {
            warn $encoded_message;
        }
    };

    $severity = 'info' if ( !defined $severity );
    if( $severity eq 'info' ) {
        infof $message;
    }
    elsif ( $severity eq 'warn' || $severity eq 'warning' ) {
        warnf $message;
    }
    elsif( $severity eq 'crit' || $severity eq 'critical' ) {
        critf $message;
    }
    else {
        debugf $message;
    }

}



1;
__END__

=head1 NAME

App::MilkianBot - ミルキィホームズとか中の人っぽい発言をおいかける bot です。

=head1 SYNOPSIS

興味がある人は @milkian_bot をフォローしてね。

=head1 DESCRIPTION

=over 2

=item 中の人の tweet を公式 RT します

=item @milkian_bot に「TMTOWTDI」または「There's more than one way to do it」というメンションを投げると、「正解はひとつ！じゃない！！」と返します。

=item @milkian_bot に「俺のタンメンまだー？」というメンションを投げると、「まだですぅー」と返します。

=back

=head1 AUTHOR

takuya.tsuchida E<lt>tsucchi {at} cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
