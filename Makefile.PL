use inc::Module::Install;
name 'App-MilkianBot';
all_from             'lib/App/MilkianBot.pm';
readme_from          'lib/App/MilkianBot.pm';
readme_markdown_from 'lib/App/MilkianBot.pm';

requires 'App::FanBot';
requires 'AnyEvent::Twitter::Stream';
requires 'Net::SSLeay';
requires 'Class::Accessor::Lite';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
