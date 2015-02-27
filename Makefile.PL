use inc::Module::Install;

RTx('RT-Extension-OneTimeTo');

repository('https://github.com/bestpractical/rt-extension-onetimeto');

requires_rt("4.0.11");

sign;
&WriteAll;
