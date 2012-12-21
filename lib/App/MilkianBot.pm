package App::MilkianBot;
use strict;
use warnings;
use Class::Accessor::Lite (
    ro => ['my_id', '_cred', '_following_ids'],
);
use AnyEvent::Twitter;
use Config::Pit;

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
    };
    bless $self, $class;
    $self->_init_credential();
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

# 単発の tweet を投げます
sub simple_tweet {
    my ($self, $tweet) = @_;

    my $done = AnyEvent->condvar;
    my $twitty = AnyEvent::Twitter->new($self->credential);
    $done->begin;
    $twitty->post('statuses/update', {
        status => $tweet,
    }, sub {
        my ($header, $response, $reason) = @_;
        $done->end;
    });
    $done->recv;
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
