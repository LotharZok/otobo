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

package Kernel::Output::HTML::ArticleAction::MarkAsImportant;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Ticket::Article',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub CheckAccess {
    my ( $Self, %Param ) = @_;

    # Check needed stuff.
    for my $Needed (qw(Ticket Article ChannelName UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check if current user is owner or responsible
    if (
        $Param{UserID} == $Param{Ticket}->{OwnerID}
        || (
            $ConfigObject->Get('Ticket::Responsible')
            && $Param{UserID} == $Param{Ticket}->{ResponsibleID}
        )
        )
    {
        return 1;
    }

    return 0;
}

sub GetConfig {
    my ( $Self, %Param ) = @_;

    # Check needed stuff.
    for my $Needed (qw(Ticket Article UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # Always use user id 1 because other users also have to see the important flag
    my %ArticleFlags = $Kernel::OM->Get('Kernel::System::Ticket::Article')->ArticleFlagGet(
        ArticleID => $Param{Article}->{ArticleID},
        UserID    => 1,
    );

    my $ArticleIsImportant = $ArticleFlags{Important};

    my $Link        = "Action=AgentTicketZoom;Subaction=MarkAsImportant;TicketID=$Param{Ticket}->{TicketID};ArticleID=$Param{Article}->{ArticleID}";
    my $Description = Translatable('Mark');
    if ($ArticleIsImportant) {
        $Description = Translatable('Unmark');
    }

    # set important menu item
    my %MenuItem = (
        ItemType    => 'Link',
        Description => $Description,
        Name        => $Description,
        Link        => $Link,
    );

    return ( \%MenuItem );
}

1;
