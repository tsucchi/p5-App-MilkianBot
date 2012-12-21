use inc::Module::Install;
name 'App-MilkianBot';
all_from             'lib/App/MilkianBot.pm';
readme_from          'lib/App/MilkianBot.pm';
readme_markdown_from 'lib/App/MilkianBot.pm';

requires 'Config::Pit';
requires 'AnyEvent::Twitter';
requires 'AnyEvent::Twitter::Stream';
requires 'Net::SSLeay';
requires 'App::Daemon';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
