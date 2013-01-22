use inc::Module::Install;

RTx('RT-Extension-OneTimeTo');
all_from('lib/RT/Extension/OneTimeTo.pm');
readme_from('lib/RT/Extension/OneTimeTo.pm');

requires_rt("4.0.6");

# Check that EscapeJS is available
{
    require RT::Interface::Web;
    die <<EOT unless RT::Interface::Web->can("EscapeJS");

Your RT install must be:

  a) version 4.0.6 or newer, OR
  b) version 4.0.0 or newer *and* have the 22 May 2012 security patches applied.

EOT
}

sign;
&WriteAll;
