package App::MilkianBot;
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite (
    ro => ['my_id', '_cred', '_following_ids', 'twitty', '_mention_for'],
);

use AnyEvent::Twitter;
use Config::Pit;
use Net::SSLeay; # for AnyEvent::Twitter::Stream
use AnyEvent::Twitter::Stream;
use List::MoreUtils qw(any);

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    my $self = {
        my_id => '962596830', #milkian_bot
        _following_ids => [
            '114700374', #'mimori_suzuko',
            '261196483', #'tokui_sorangley',
            '244788445', #'mikoiwate_351',
            '161910608', #'izugyoza',
            '94825321',  #'milkyholmes',
        ],
        _mention_for => {
            qr/TMTOWTDI/                             => '正解はひとつ！じゃない！！',
            qr/There's more than one way to do it/   => '正解はひとつ！じゃない！！',
            qr/(俺|オレ)のタンメンまだ(ー|〜)?(\?|？)/ => 'まだですぅー',
        },
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

    my $cv = AnyEvent->condvar;
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
            print "ERROR: $error";
            $cv->send;
        },
        on_eof   => sub {
            print "EOF\n";
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
        print "retweeted: $user : $text\n";
    });
}

# メンションに対して特定のキーワードが含まれている場合に reply を返す
# 例) 「俺のタンメンまだー？」 => 「まだですぅー」
sub reply_to_mention_using_keyword {
    my ($self, $id, $user, $text) = @_;
    print "$user : $text\n";
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
                print "$reply_message\n";
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
