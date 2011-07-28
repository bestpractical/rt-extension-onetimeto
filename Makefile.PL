use inc::Module::Install;

RTx('RT-Extension-OneTimeTo');
all_from('lib/RT/Extension/OneTimeTo.pm');

sign;
&WriteAll;
