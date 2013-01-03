#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use App::Daemon qw(daemonize);
use FindBin;
use lib "$FindBin::RealBin/../lib";
use App::MilkianBot;
use Proclet;

daemonize();

my $is_background = $App::Daemon::background;

if( $is_background ) {
    run_bot();
}
else {
    my $proclet = Proclet->new;
    $proclet->service( code => \&run_bot );
    $proclet->run;
}



sub run_bot {
    my $bot = App::MilkianBot->new({ background => $is_background });
    $bot->run;
}
