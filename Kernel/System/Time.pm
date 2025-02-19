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

package Kernel::System::Time;

use strict;
use warnings;

use Kernel::System::DateTime;

use Kernel::System::VariableCheck qw( IsArrayRefWithData IsHashRefWithData );

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Time - time functions. DEPRECATED, for new code use Kernel::System::DateTime instead.

=head1 DESCRIPTION

This module is managing time functions.

=head1 PUBLIC INTERFACE

=head2 new()

create a time object. Do not use it directly, instead use:

    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = 0;

    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');

    $Self->{TimeZone} = $Param{TimeZone}
        || $Param{UserTimeZone}
        || $DateTimeObject->OTOBOTimeZoneGet();

    # check if time zone is valid
    if ( !$DateTimeObject->IsTimeZoneValid( TimeZone => $Self->{TimeZone} ) ) {

        my $InvalidTimeZone = $Self->{TimeZone};

        $Self->{TimeZone} = $Param{UserTimeZone}
            ? $DateTimeObject->UserDefaultTimeZoneGet()
            : $DateTimeObject->OTOBOTimeZoneGet();

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid time zone $InvalidTimeZone, using $Self->{TimeZone} as fallback.",
        );
    }

    return $Self;
}

=head2 SystemTime()

returns the number of non-leap seconds since what ever time the
system considers to be the epoch (that's 00:00:00, January 1, 1904
for Mac OS, and 00:00:00 UTC, January 1, 1970 for most other systems).

    my $SystemTime = $TimeObject->SystemTime();

=cut

sub SystemTime {
    my $Self = shift;

    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
    my $SystemTime     = $DateTimeObject->ToEpoch();

    return $SystemTime;
}

=head2 SystemTime2TimeStamp()

returns a time stamp for a given system time in C<yyyy-mm-dd 23:59:59> format.

    my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

If you need the short format "23:59:59" for dates that are "today",
pass the Type parameter like this:

    my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
        Type       => 'Short',
    );

=cut

sub SystemTime2TimeStamp {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{SystemTime} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SystemTime!',
        );
        return;
    }

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $Self->SystemTime2Date(%Param);
    if ( defined $Param{Type} && $Param{Type} eq 'Short' ) {
        my ( $CSec, $CMin, $CHour, $CDay, $CMonth, $CYear ) = $Self->SystemTime2Date(
            SystemTime => $Self->SystemTime(),
        );
        if ( $CYear == $Year && $CMonth == $Month && $CDay == $Day ) {
            return "$Hour:$Min:$Sec";
        }
        return "$Year-$Month-$Day $Hour:$Min:$Sec";
    }
    return "$Year-$Month-$Day $Hour:$Min:$Sec";
}

=head2 CurrentTimestamp()

returns a time stamp of the local system time (see L<SystemTime()>)
in C<yyyy-mm-dd 23:59:59> format.

    my $TimeStamp = $TimeObject->CurrentTimestamp();

=cut

sub CurrentTimestamp {
    my ( $Self, %Param ) = @_;

    return $Self->SystemTime2TimeStamp( SystemTime => $Self->SystemTime() );
}

=head2 SystemTime2Date()

converts a system time to a structured date array.

    my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );

$WeekDay is the day of the week, with 0 indicating Sunday and 3 indicating Wednesday.

=cut

sub SystemTime2Date {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{SystemTime} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SystemTime!',
        );
        return;
    }

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            Epoch => $Param{SystemTime},
        },
    );

    $DateTimeObject->ToTimeZone( TimeZone => $Self->{TimeZone} );

    my $DateTimeValues = $DateTimeObject->Get();

    my $Year  = $DateTimeValues->{Year};
    my $Month = sprintf "%02d", $DateTimeValues->{Month};
    my $Day   = sprintf "%02d", $DateTimeValues->{Day};
    my $Hour  = sprintf "%02d", $DateTimeValues->{Hour};
    my $Min   = sprintf "%02d", $DateTimeValues->{Minute};
    my $Sec   = sprintf "%02d", $DateTimeValues->{Second};

    my $WDay = $DateTimeValues->{DayOfWeek} == 7 ? 0 : $DateTimeValues->{DayOfWeek};

    return ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay );
}

=head2 TimeStamp2SystemTime()

converts a given time stamp to system time.

    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '2004-08-14 22:45:00',
    );

=cut

sub TimeStamp2SystemTime {
    my ( $Self, %Param ) = @_;

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            TimeZone => $Self->{TimeZone},
        },
    );

    return $DateTimeObject->TimeStamp2SystemTime(%Param);
}

=head2 Date2SystemTime()

converts a structured date array to system time of OTOBO.
In this context system time is the epoch.

    my $SystemTime = $TimeObject->Date2SystemTime(
        Year   => 2004,
        Month  => 8,
        Day    => 14,
        Hour   => 22,
        Minute => 45,
        Second => 0,
    );

=cut

sub Date2SystemTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Year Month Day Hour Minute Second)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            %Param,
            TimeZone => $Self->{TimeZone},
        },
    );

    if ( !$DateTimeObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  =>
                "Invalid Date '$Param{Year}-$Param{Month}-$Param{Day} $Param{Hour}:$Param{Minute}:$Param{Second}'!",
        );
        return;
    }

    return $DateTimeObject->ToEpoch();
}

=head2 ServerLocalTimeOffsetSeconds()

All framework code that calls this method only uses it to check if the server runs in UTC
and therefore user time zones are allowed. It's not needed any more in the future and is only
in here to don't break code that has not been ported yet. It returns 0 to tell its callers
that the server runs in UTC and so user time zones are allowed/active.

( originally returned the computed difference in seconds between UTC time and local time. )

    my $ServerLocalTimeOffsetSeconds = $TimeObject->ServerLocalTimeOffsetSeconds(
        SystemTime => $SystemTime,  # optional, otherwise call time()
    );

=cut

sub ServerLocalTimeOffsetSeconds {
    my ( $Self, %Param ) = @_;

    return 0;
}

=head2 MailTimeStamp()

returns the current time stamp in RFC 2822 format to be used in email headers:
"Wed, 22 Sep 2014 16:30:57 +0200".

    my $MailTimeStamp = $TimeObject->MailTimeStamp();

=cut

sub MailTimeStamp {
    my ( $Self, %Param ) = @_;

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            TimeZone => $Self->{TimeZone},
        },
    );

    my $EmailTimeStamp = $DateTimeObject->ToEmailTimeStamp();

    return $EmailTimeStamp;
}

=head2 WorkingTime()

get the working time in seconds between these local system times.

    my $WorkingTime = $TimeObject->WorkingTime(
        StartTime => $Created,
        StopTime  => $TimeObject->SystemTime(),
    );

    my $WorkingTime = $TimeObject->WorkingTime(
        StartTime => $Created,
        StopTime  => $TimeObject->SystemTime(),
        Calendar  => 3, # '' is default
    );

=cut

sub WorkingTime {
    my ( $Self, %Param ) = @_;

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            TimeZone => $Self->{TimeZone},
        },
    );

    my $Delta = $DateTimeObject->WorkingTime(%Param);

    return $Delta->{AbsoluteSeconds};
}

=head2 DestinationTime()

get the destination time based on the current calendar working time (fallback: default
system working time) configuration.

Returns a system time (integer time stamp).

The algorithm roughly works as follows:
    - Check if the start time is actually in the configured working time.
        - If not, set it to the next working time second. Example: start time is
            on a weekend, start time would be set to 8:00 on the following Monday.
    - Then the diff time (in seconds) is added to the start time incrementally, only considering
        the configured working times. So adding 24 hours could actually span multiple days because
        they would be spread over the configured working hours. If we have 8-20, 24 hours would be
        spread over 2 days (13/11 hours).

NOTE: Currently, the implementation stops silently after 600 iterations, making it impossible to
    specify longer escalation times, for example.

    my $DestinationTime = $TimeObject->DestinationTime(
        StartTime => $Created,
        Time      => 60*60*24*2,
    );

    my $DestinationTime = $TimeObject->DestinationTime(
        StartTime => $Created,
        Time      => 60*60*24*2,
        Calendar  => 3, # '' is default
    );

=cut

sub DestinationTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw( StartTime Time )) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return $Param{StartTime} if $Param{Time} <= 0;

    my $DestinationDateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            Epoch    => $Param{StartTime},
            TimeZone => $Self->{TimeZone},
        },
    );

    $DestinationDateTimeObject->Add(
        Seconds       => $Param{Time},
        AsWorkingTime => 1,
        Calendar      => $Param{Calendar},
    );

    my $DestinationTime = $DestinationDateTimeObject->ToEpoch();

    return $DestinationTime;
}

=head2 VacationCheck()

check if the selected day is a vacation (it does not matter if you
insert 01 or 1 for month or day in the function or in the SysConfig)

returns (true) vacation day if exists, returns false if date is no
vacation day

    $TimeObject->VacationCheck(
        Year     => 2005,
        Month    => 7 || '07',
        Day      => 13,
    );

    $TimeObject->VacationCheck(
        Year     => 2005,
        Month    => 7 || '07',
        Day      => 13,
        Calendar => 3, # '' is default; 0 is handled like ''
    );

=cut

sub VacationCheck {
    my ( $Self, %Param ) = @_;

    # check required params
    for (qw(Year Month Day)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "VacationCheck: Need $_!",
            );
            return;
        }
    }

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            %Param,
            TimeZone => $Self->{TimeZone},
        },
    );
    return $DateTimeObject->IsVacationDay(
        Calendar => $Param{Calendar},
    );
}

1;
