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

use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use Kernel::System::UnitTest::RegisterDriver;

use vars (qw($Self));

use File::Basename;
use Kernel::System::VariableCheck qw( :all );

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $HelperObject       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $MainObject         = $Kernel::OM->Get('Kernel::System::Main');
my $YAMLObject         = $Kernel::OM->Get('Kernel::System::YAML');
my $SysConfigObject    = $Kernel::OM->Get('Kernel::System::SysConfig');
my $SysConfigDBObject  = $Kernel::OM->Get('Kernel::System::SysConfig::DB');
my $SysConfigXMLObject = $Kernel::OM->Get('Kernel::System::SysConfig::XML');
my $RandomID           = $HelperObject->GetRandomID();

my @Tests = (
    {
        Title  => 'Missing Settings.',
        Params => {
            UserID => 1,
        },
        ExpectedResult => undef,
    },
    {
        Title  => 'Settings must be hash.',
        Params => {
            Settings => 'Settings',    # Wrong
            UserID   => 1,
        },
        ExpectedResult => undef,
    },
    {
        Title  => 'Missing UserID.',
        Params => {
            Settings => [
                "TestSettingName$RandomID",
            ],
        },
        ExpectedResult => undef,
    },
    {
        Title  => 'Settings empty.',
        Params => {
            Settings => {},
            UserID   => 1,
        },
        ExpectedResult => 1,    # Nothing to do, but thats OK.
    },
    {
        Title  => 'Load setting from Example.xml.',
        Params => {
            LoadXML => '/scripts/test/sample/SysConfig/XML/AdminSystemConfiguration/Example.xml',
            UserID  => 1,
        },
        ExpectedResult => 1,
    },
    {
        Title  => 'Load setting from ExampleComplex.xml.',
        Params => {
            LoadXML => '/scripts/test/sample/SysConfig/XML/AdminSystemConfiguration/ExampleComplex.xml',
            UserID  => 1,
        },
        ExpectedResult => 1,
    },
);

TEST:
for my $Test (@Tests) {

    my %LoadedData;

    if ( $Test->{Params}->{LoadXML} ) {
        my $ConfigFile = $MainObject->FileRead(
            Location => $ConfigObject->Get('Home') . $Test->{Params}->{LoadXML},
            Mode     => 'utf8',
            Result   => 'SCALAR',
        );

        $Self->True(
            ref $ConfigFile && ${$ConfigFile},
            'ConfigFile loaded',
        );

        if ( !ref $ConfigFile || !${$ConfigFile} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't open file $Test->{LoadXML}!",
            );
            next TEST;
        }

        # Remove comments.
        ${$ConfigFile} =~ s{<!--.*?-->}{}gs;

        my $XMLFilename = basename( $Test->{Params}->{LoadXML} );

        my @ParsedSettings = $SysConfigXMLObject->SettingListParse(
            XMLInput    => ${$ConfigFile},
            XMLFilename => $XMLFilename,
        );

        for my $Setting (@ParsedSettings) {

            my $EffectiveValue = $SysConfigObject->SettingEffectiveValueGet(
                Value => $Setting->{XMLContentParsed}->{Value},
            );
            $Setting->{EffectiveValue} = $YAMLObject->Dump(
                Data => $EffectiveValue,
            );
            $Setting->{XMLContentParsedYAML} = $YAMLObject->Dump(
                Data => $Setting->{XMLContentParsed},
            );
            $LoadedData{Settings}->{ $Setting->{XMLContentParsed}->{Name} } = $Setting;
        }

        $Self->True(
            IsHashRefWithData( $LoadedData{Settings} ),
            'Check if there are loaded settings present',
        );
    }

    my $Result = $SysConfigDBObject->DefaultSettingBulkAdd(
        %{ $Test->{Params} },
        %LoadedData,
    );

    $Self->Is(
        $Result,
        $Test->{ExpectedResult},
        "DefaultSettingBulkAdd() - $Test->{Title}",
    );

    if ( %LoadedData && scalar keys %{ $LoadedData{Settings} } ) {

        # Make sure that settings are really present in the system.
        my @SettingList    = $SysConfigObject->ConfigurationList();
        my %NavigationTree = $SysConfigObject->ConfigurationNavigationTree();

        for my $SettingName ( sort keys %{ $LoadedData{Settings} } ) {
            my $FoundInSettingList = grep { $_->{Name} eq $SettingName } @SettingList;
            $Self->True(
                $FoundInSettingList,
                "ConfigurationList() contains $SettingName",
            );

            my %Setting = $SysConfigObject->SettingGet(
                Name => $SettingName,
            );

            $Self->True(
                %Setting ? 1 : 0,
                "SettingGet() has result for $SettingName",
            );

            # NOTE: This test is working fine ATM, however if future tests contain more complex navigation,
            #       it needs to be improved.
            $Self->True(
                $NavigationTree{
                    $LoadedData{Settings}->{$SettingName}->{XMLContentParsed}->{Navigation}->[0]->{Content}
                },
                "Navigation found in NavigationTree() for $SettingName",
            );

        }
    }
}

@Tests = (
    {
        Title  => 'Missing Settings.',
        Params => {
            UserID => 1,
        },
        ExpectedResult => undef,
    },
    {
        Title  => 'Settings must be hash.',
        Params => {
            Settings => 'Settings',    # Wrong
            UserID   => 1,
        },
        ExpectedResult => undef,
    },
    {
        Title  => 'Missing UserID.',
        Params => {
            Settings => [
                "TestSettingName$RandomID",
            ],
        },
        ExpectedResult => undef,
    },

    {
        Title  => 'Settings empty.',
        Params => {
            Settings => {},
            UserID   => 1,
        },
        ExpectedResult => 1,    # Nothing to do, but thats OK.
    },
    {
        Title  => 'Load setting from Example.xml.',
        Params => {
            LoadXML => '/scripts/test/sample/SysConfig/XML/AdminSystemConfiguration/Example.xml',
            UserID  => 1,
        },
        ExpectedResult => 1,
    },
    {
        Title  => 'Load setting from ExampleComplex.xml.',
        Params => {
            LoadXML => '/scripts/test/sample/SysConfig/XML/AdminSystemConfiguration/ExampleComplex.xml',
            UserID  => 1,
        },
        ExpectedResult => 1,
    },
);

for my $Test (@Tests) {

    my %LoadedData;

    @{ $LoadedData{SettingList} } = $SysConfigObject->ConfigurationList();

    if ( $Test->{Params}->{LoadXML} ) {
        my $ConfigFile = $MainObject->FileRead(
            Location => $ConfigObject->Get('Home') . $Test->{Params}->{LoadXML},
            Mode     => 'utf8',
            Result   => 'SCALAR',
        );

        $Self->True(
            ref $ConfigFile && ${$ConfigFile},
            'ConfigFile loaded',
        );

        if ( !ref $ConfigFile || !${$ConfigFile} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't open file $Test->{LoadXML}!",
            );
            next TEST;
        }

        # Remove comments.
        ${$ConfigFile} =~ s{<!--.*?-->}{}gs;

        my $XMLFilename = basename( $Test->{Params}->{LoadXML} );

        my @ParsedSettings = $SysConfigXMLObject->SettingListParse(
            XMLInput    => ${$ConfigFile},
            XMLFilename => $XMLFilename,
        );

        for my $Setting (@ParsedSettings) {

            my $EffectiveValue = $SysConfigObject->SettingEffectiveValueGet(
                Value => $Setting->{XMLContentParsed}->{Value},
            );
            $Setting->{EffectiveValue} = $YAMLObject->Dump(
                Data => $EffectiveValue,
            );
            $Setting->{XMLContentParsedYAML} = $YAMLObject->Dump(
                Data => $Setting->{XMLContentParsed},
            );
            $LoadedData{Settings}->{ $Setting->{XMLContentParsed}->{Name} } = $Setting;
        }

        $Self->True(
            IsHashRefWithData( $LoadedData{Settings} ),
            'Check if there are loaded settings present',
        );
    }

    my $Result = $SysConfigDBObject->DefaultSettingVersionBulkAdd(
        %{ $Test->{Params} },
        %LoadedData,
    );

    $Self->Is(
        $Result,
        $Test->{ExpectedResult},
        "DefaultSettingVersionBulkAdd() - $Test->{Title}",
    );

    if ( %LoadedData && $LoadedData{Settings} ) {
        for my $SettingName ( sort keys %{ $LoadedData{Settings} } ) {

            # Testing DefaultSettingVersionListGet() we also test DefaultSettingVersionGet().
            my @List = $SysConfigDBObject->DefaultSettingVersionListGet(
                Name => $SettingName,
            );

            my $DefaultVersionFound = grep { $_->{Name} eq $SettingName } @List;

            $Self->True(
                $DefaultVersionFound,
                "Setting found in DefaultSettingVersionListGet() for $SettingName",
            );
        }
    }
}

$Self->DoneTesting();
