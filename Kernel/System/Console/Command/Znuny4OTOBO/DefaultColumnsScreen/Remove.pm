# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2012-2020 Znuny GmbH, http://znuny.com/
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## nofilter(TidyAll::Plugin::OTOBO::Legal::LicenseValidator)

package Kernel::System::Console::Command::Znuny4OTOBO::DefaultColumnsScreen::Remove;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::SysConfig',
    'Kernel::System::ZnunyHelper',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description("Removes the 'DynamicField' config of all DefaultColumnsScreens configs accordingly");

    $Self->AddOption(
        Name        => 'values',
        Description => 'Prints all possible DynamicFields and Screens.',
        Required    => 0,
        HasValue    => 0,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'dynamicfield',
        Description => 'Name of the DynamicField which should get added or updated.',
        Required    => 0,
        HasValue    => 1,
        Multiple    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'state',
        Description => 'The attribute state possible settings: 0 = Disabled, 1 = Available, 2 = Enabled by default.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'screen',
        Description => 'Names of the FrontendScreen.',
        Required    => 0,
        HasValue    => 1,
        Multiple    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $SysConfigObject    = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $ZnunyHelperObject  = $Kernel::OM->Get('Kernel::System::ZnunyHelper');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get values
    my $Values                = $Self->GetOption('values');
    my @DynamicFields         = @{ $Self->GetOption('dynamicfield') // [] };
    my $DynamicFieldState     = $Self->GetOption('state');
    my @DefaultColumnsScreens = @{ $Self->GetOption('screen') // [] };

    # get all dynamicFields
    my %DynamicFieldList            = %{ $DynamicFieldObject->DynamicFieldList( ResultType => 'HASH' ) };
    my %DynamicFieldListReverse     = reverse %DynamicFieldList;
    my @DynamicFieldList            = values %DynamicFieldList;
    my $ValidDynamicFieldScreenList = $ZnunyHelperObject->_ValidDynamicFieldScreenListGet();

    my @DefaultColumnsScreensConfig = @{ $ValidDynamicFieldScreenList->{DefaultColumnsScreens} };

    if ( !@DefaultColumnsScreens ) {
        @DefaultColumnsScreens = @DefaultColumnsScreensConfig;
    }

    # show all possible values (screens and dynamic fields)
    if ($Values) {

        $Self->Print("\n<green>DynamicFields:</green>");
        for my $DynamicField (@DynamicFieldList) {
            $Self->Print("\n$DynamicField");
        }

        $Self->Print("\n\n<green>Screens:</green>");
        for my $Screen (@DefaultColumnsScreens) {
            $Self->Print("\n$Screen");
        }
        $Self->Print("\n");
        return $Self->ExitCodeOk();
    }

    if ( !@DynamicFields ) {
        $Self->Print("\n<red>DynamicField is Required!</red>\n");
        $Self->Print( $Self->GetUsageHelp() );
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Updating the 'DynamicField' SysConfigs ...</green>");

    my %Screens = ();
    SCREENS:
    for my $Screen (@DefaultColumnsScreens) {
        $Self->Print("\n\nScreen:       <yellow>$Screen</yellow>");

        my $IsDefaultColumnScreen = grep { $Screen eq $_ } @DefaultColumnsScreensConfig;

        if ( !$IsDefaultColumnScreen ) {
            $Self->Print("\n<red>DefaultColumnsScreens: '$Screen' not exists!</red>");
            next SCREENS if !$IsDefaultColumnScreen;
        }
        $Screens{$Screen} ||= {};

        DYNAMICFIELD:
        for my $DynamicField (@DynamicFields) {

            if ( !$DynamicFieldListReverse{$DynamicField} ) {
                $Self->Print("\n<red>DynamicField: '$DynamicField' not exists!</red>");
            }
            next DYNAMICFIELD if !$DynamicFieldListReverse{$DynamicField};

            $Self->Print("\nDynamicField: <yellow>$DynamicField</yellow>");

            $Screens{$Screen}->{"DynamicField_$DynamicField"} = 1;
        }

        # no GuardClause :)
    }

    $ZnunyHelperObject->_DefaultColumnsDisable(%Screens);

    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;
