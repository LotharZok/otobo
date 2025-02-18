# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::Console::Command::Maint::PostMaster::Read;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::CommunicationLog',
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Read incoming email from STDIN.');
    $Self->AddOption(
        Name        => 'target-queue',
        Description => "Preselect a target queue by name.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'untrusted',
        Description => "This will cause X-OTOBO email headers to be ignored.",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # start a new incoming communication
    my $CommunicationLogObject = $Kernel::OM->Create(
        'Kernel::System::CommunicationLog',
        ObjectParams => {
            Transport   => 'Email',
            Direction   => 'Incoming',
            AccountType => 'STDIN',
        },
    );

    # start object log for the incoming connection
    $CommunicationLogObject->ObjectLogStart( ObjectLogType => 'Connection' );

    $CommunicationLogObject->ObjectLog(
        ObjectLogType => 'Connection',
        Priority      => 'Debug',
        Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
        Value         => 'Read email from STDIN.',
    );

    # get email from SDTIN
    my @Email = <STDIN>;    ## no critic qw(InputOutput::ProhibitExplicitStdin)

    if ( !@Email ) {

        $CommunicationLogObject->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Error',
            Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
            Value         => 'Got no email on STDIN!',
        );

        $CommunicationLogObject->ObjectLogStop(
            ObjectLogType => 'Connection',
            Status        => 'Failed',
        );
        $CommunicationLogObject->CommunicationStop( Status => 'Failed' );

        return $Self->ExitCodeError(1);
    }

    $CommunicationLogObject->ObjectLog(
        ObjectLogType => 'Connection',
        Priority      => 'Debug',
        Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
        Value         => 'Email with ' . ( scalar @Email ) . ' lines successfully read from STDIN.',
    );

    # start object log for the email processing
    $CommunicationLogObject->ObjectLogStart( ObjectLogType => 'Message' );

    # remember the return code to stop the communictaion later with a proper status
    my $PostMasterReturnCode = 0;

    # Wrap the main part of the script in an "eval" block so that any
    # unexpected (but probably transient) fatal errors (such as the
    # database being unavailable) can be trapped without causing a
    # bounce
    eval {

        $CommunicationLogObject->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Debug',
            Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
            Value         => 'Processing email with PostMaster module.',
        );

        my $PostMasterObject = $Kernel::OM->Create(
            'Kernel::System::PostMaster',
            ObjectParams => {
                CommunicationLogObject => $CommunicationLogObject,
                Email                  => \@Email,
                Trusted                => $Self->GetOption('untrusted') ? 0 : 1,
            },
        );

        my @Return = $PostMasterObject->Run(
            Queue => $Self->GetOption('target-queue'),
        );

        if ( !$Return[0] ) {

            $CommunicationLogObject->ObjectLog(
                ObjectLogType => 'Message',
                Priority      => 'Error',
                Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
                Value         => 'PostMaster module exited with errors, could not process email. Please refer to the log!',
            );
            $CommunicationLogObject->CommunicationStop( Status => 'Failed' );

            die "Could not process email. Please refer to the log!\n";
        }

        my $Dump = $Kernel::OM->Get('Kernel::System::Main')->Dump( \@Return );
        $CommunicationLogObject->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Debug',
            Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
            Value         => "Email processing with PostMaster module completed, return data: $Dump",
        );

        $PostMasterReturnCode = $Return[0];
    };

    if ($@) {

        # An unexpected problem occurred (for example, the database was
        # unavailable). Return an EX_TEMPFAIL error to cause the mail
        # program to requeue the message instead of immediately bouncing
        # it; see sysexits.h. Most mail programs will retry an
        # EX_TEMPFAIL delivery for about four days, then bounce the
        # message.)
        my $Message = $@;

        $CommunicationLogObject->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Error',
            Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
            Value         => "An unexpected error occurred, message: $Message",
        );

        $CommunicationLogObject->ObjectLogStop(
            ObjectLogType => 'Message',
            Status        => 'Failed',
        );
        $CommunicationLogObject->ObjectLogStop(
            ObjectLogType => 'Connection',
            Status        => 'Failed',
        );
        $CommunicationLogObject->CommunicationStop( Status => 'Failed' );

        return $Self->ExitCodeError(75);
    }

    $CommunicationLogObject->ObjectLog(
        ObjectLogType => 'Connection',
        Priority      => 'Debug',
        Key           => 'Kernel::System::Console::Command::Maint::PostMaster::Read',
        Value         => 'Closing connection from STDIN.',
    );

    $CommunicationLogObject->ObjectLogStop(
        ObjectLogType => 'Message',
        Status        => 'Successful',
    );
    $CommunicationLogObject->ObjectLogStop(
        ObjectLogType => 'Connection',
        Status        => 'Successful',
    );

    my %ReturnCodeMap = (
        0 => 'Failed',        # error (also false)
        1 => 'Successful',    # new ticket created
        2 => 'Successful',    # follow up / open/reopen
        3 => 'Successful',    # follow up / close -> new ticket
        4 => 'Failed',        # follow up / close -> reject
        5 => 'Successful',    # ignored (because of X-OTOBO-Ignore header)
    );

    $CommunicationLogObject->CommunicationStop(
        Status => $ReturnCodeMap{$PostMasterReturnCode} // 'Failed',
    );

    return $Self->ExitCodeOk();
}

1;
