package RT::Extension::OneTimeTo;
use strict;
use warnings;
no warnings 'redefine';

our $VERSION = '0.01';

use RT::Interface::Web;
my $orig_process = HTML::Mason::Commands->can('_ProcessUpdateMessageRecipients');
*HTML::Mason::Commands::_ProcessUpdateMessageRecipients = sub {
    $orig_process->(@_);

    my %args = (
        ARGSRef           => undef,
        TicketObj         => undef,
        MessageArgs       => undef,
        @_,
    );

    my $to = $args{ARGSRef}->{'UpdateTo'};

    my $message_args = $args{MessageArgs};

    $message_args->{ToMessageTo} = $to;

    # transform UpdateTo into ToMessageTo; mostly copied from the original method
    unless ( $args{'ARGSRef'}->{'UpdateIgnoreAddressCheckboxes'} ) {
        foreach my $key ( keys %{ $args{ARGSRef} } ) {
            next unless $key =~ /^UpdateTo-(.*)$/;

            my $var   = 'ToMessageTo';
            my $value = $1;
            if ( $message_args->{$var} ) {
                $message_args->{$var} .= ", $value";
            } else {
                $message_args->{$var} = $value;
            }
        }
    }
};

use RT::Ticket;
my $orig_note = RT::Ticket->can('_RecordNote');
*RT::Ticket::_RecordNote = sub {
    my $self = shift;
    my %args = @_;

    # lazily initialize the MIMEObj if needed; copied from original method
    unless ( $args{'MIMEObj'} ) {
        $args{'MIMEObj'} = MIME::Entity->build(
            Data => ( ref $args{'Content'}? $args{'Content'}: [ $args{'Content'} ] )
        );
    }

    # if there's a one-time To, add it to the MIMEObj
    my $type = 'To';
    if ( defined $args{ $type . 'MessageTo' } ) {

        my $addresses = join ', ', (
            map { RT::User->CanonicalizeEmailAddress( $_->address ) }
                Email::Address->parse( $args{ $type . 'MessageTo' } ) );
        $args{'MIMEObj'}->head->add( 'RT-Send-' . $type, Encode::encode_utf8( $addresses ) );
    }

    return $orig_note->($self, %args);
};

use RT::Action::Notify;
my $orig_recipients = RT::Action::Notify->can('SetRecipients');
*RT::Action::Notify::SetRecipients = sub {
    my $self = shift;
    $orig_recipients->($self, @_);

    # copy RT-Send-To addresses to To addresses
    if ( $self->Argument =~ /\bOtherRecipients\b/ ) {
        if ( my $attachment = $self->TransactionObj->Attachments->First ) {
            push @{ $self->{'To'} }, map { $_->address } Email::Address->parse(
                $attachment->GetHeader('RT-Send-To')
            );
        }
    }

    # deal with NotifyActor, mostly copied from the original method
    my $creatorObj = $self->TransactionObj->CreatorObj;
    my $creator = $creatorObj->EmailAddress();
    my $TransactionCurrentUser = RT::CurrentUser->new;
    $TransactionCurrentUser->LoadByName($creatorObj->Name);
    if (!RT->Config->Get('NotifyActor',$TransactionCurrentUser)) {
        @{ $self->{'To'} }  = grep ( lc $_ ne lc $creator, @{ $self->{'To'} } );
    }
};

1;

__END__

=head1 NAME

RT::Extension::OneTimeTo - add one-time To box to Update page

=head1 AUTHOR

Shawn M Moore C<< <sartak@bestpractical.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

