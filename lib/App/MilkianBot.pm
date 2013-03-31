package App::MilkianBot;
use parent qw(App::FanBot);
use strict;
use warnings;
use utf8;
use Class::Accessor::Lite (
    ro => ['_mention_for']
);

use Net::SSLeay; # for AnyEvent::Twitter::Stream
use AnyEvent::Twitter::Stream;
use Encode;
use Time::Piece;

our $VERSION = '0.03';

sub new {
    my ($class, $option_href) = @_;
    $option_href->{app_name} = 'milkian_bot';
    my $self = $class->SUPER::new($option_href);
    my %option = (
        my_id => '962596830', #milkian_bot
        _official_ids => [
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
        _exclude_patterns => [ # 定期ポストなどを除外
            '^RT',
            '#_キョクナビ',
            '#nowplaying',
            '#なうぷれ',
            '【拡散希望】',
            '#RTした人フォローする',
            '#RTした人全員フォローする',
            'そらまる団',
            # どうやら中の人たちと同じ渾名をもってる方(みもりんっていっぱいいるのね。。。)
            '@Mimo_Rine',
            '@mmry09',
            '@kamekazu_m',
            '@mimori_ageha',
        ],
        _exclude_users => [ # bot とか定期しかつぶやいてない人などを除外
            'Hercule_B',
            'Cordelia_G',
            'reon8hirockyy',
            'haru___sora',
            'haru___sora2',
            'haru___sora3',
            'y_gates',
            'tohoku_kitainu',
            'Cordeliabot',
            'G4_Hirano_chan',
            'Hercule_bot',
            'Souseki_I',
            'Nero_9z',
            'Yamazaki_8_bot',
            'Nakatani_m_bot',
            'butazuraTruk',
            'nanakorokke',
            'mera_azusa',
            'Furuhashi_bot',
            'Harasawa_bot',
            'Yoh_T_bot',
            'animejoho_ds4',
            'animejoho_z72',
            'animejoho_vc3',
            'animejoho_g17',
            'animejoho_252',
            'animejoho_a09',
            'animejoho_ss1',
            'MukTom',
            'Kazami_Kazuki',
            'yukari_A_bot',
            'benymd_bot',
            'kyou_jza',
            'shinshiyamap',
            'Rin_Hoshizora',
            'Now_Mitha',
        ],
        _search_keywords => [
            '#milkyholmes',
            'ミルキィホームズ',
            'みもりん',
            'そらまる',
            'みころん',
            'いず様',
            '三森すずこ',
            '徳井青空',
            '佐々木未来',
            '橘田いずみ',
        ],
    );
    $self = { %{ $self }, %option  };
    bless $self, $class;
}

sub mention_for {
    my ($self) = @_;
    return %{ $self->_mention_for };
}


# bot として実行します。
sub run {
    my ($self) = @_;

    $self->logging('start', 'warn');
    $self->update_latest_since_id();

    my $cv = AnyEvent->condvar;
    my $good_morning_timer = $self->good_morning_timer();
    my $search_timer = $self->search_timer();

    my $listener = AnyEvent::Twitter::Stream->new(
        $self->credential,
        method   => 'filter',
        follow   => join(',', ($self->official_ids, $self->my_id)),
        on_tweet => sub {
            my $tweet = shift;
            my $user = $tweet->{user}->{screen_name};
            my $text = ($tweet->{text} || '');

            return unless $user && $text;

            if ( $self->is_official($tweet) ) {
                $self->do_rt($tweet->{id}, $user, $text);
            }
            if ( $self->is_mention_to_me($tweet) ) {
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


1;
__END__

=head1 NAME

App::MilkianBot - ミルキィホームズとか中の人っぽい発言をおいかける bot です。

=head1 SYNOPSIS

興味がある人は @milkian_bot をフォローしてね。興味がなくて、RT されるのがウザいと思う方はお手数ですがブロックしてください。

=head1 DESCRIPTION

=over 2

=item 中の人の tweet を公式 RT します

=item @milkian_bot に「TMTOWTDI」または「There's more than one way to do it」というメンションを投げると、「正解はひとつ！じゃない！！」と返します。

=item @milkian_bot に「俺のタンメンまだー？」というメンションを投げると、「まだですぅー」と返します。

=item ミルキィホームズとか、中の人っぽい話題を検索して、RT します。邪魔だと思われる方は、お手数ですが @milkian_bot をブロックしてください。

=back

=head1 AUTHOR

takuya.tsuchida E<lt>tsucchi {at} cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
