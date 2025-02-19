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

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

#
# Prepare valid config XML and Perl
#
my $ValidSettingXML = <<'EOF',
<?xml version="1.0" encoding="utf-8" ?>
<otobo_config version="2.0" init="Framework">
    <Setting Name="Test1" Required="1" Valid="1">
        <Description Translatable="1">Test 1.</Description>
        <Navigation>Core::Ticket</Navigation>
        <Value>
            <Item ValueType="String" ValueRegex=".*">Test setting 1</Item>
        </Value>
    </Setting>
    <Setting Name="Test2" Required="1" Valid="1">
        <Description Translatable="1">Test 2.</Description>
        <Navigation>Core::Ticket</Navigation>
        <Value>
            <Item ValueType="File">/usr/bin/gpg</Item>
        </Value>
    </Setting>
</otobo_config>
EOF

    my $SysConfigXMLObject = $Kernel::OM->Get('Kernel::System::SysConfig::XML');

my @DefaultSettingAddParams = $SysConfigXMLObject->SettingListParse(
    XMLInput => $ValidSettingXML,
);

my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
$DateTimeObject->Add( Minutes => 30 );

my $SysConfigDBObject = $Kernel::OM->Get('Kernel::System::SysConfig::DB');

my $SettingName = 'ProductName ' . $HelperObject->GetRandomNumber();

# Add default setting
my $DefaultSettingID = $SysConfigDBObject->DefaultSettingAdd(
    Name                     => $SettingName,
    Description              => 'Defines the name of the application ...',
    Navigation               => 'ASimple::Path::Structure',
    IsInvisible              => 0,
    IsReadonly               => 0,
    IsRequired               => 1,
    IsValid                  => 1,
    HasConfigLevel           => 200,
    UserModificationPossible => 0,
    UserModificationActive   => 0,
    XMLContentRaw            => $DefaultSettingAddParams[0]->{XMLContentRaw},
    XMLContentParsed         => $DefaultSettingAddParams[0]->{XMLContentParsed},
    XMLFilename              => 'UnitTest.xml',
    EffectiveValue           => 'Test setting 1',
    UserID                   => 1,
);

my $Result = $DefaultSettingID ? 1 : 0;

$Self->Is(
    $Result,
    1,
    'DefaultSettingAdd() must succeed.',
);

# Get testing random number
my $RandomNumber = $HelperObject->GetRandomNumber();

my $FileName = 'ConfigItem' . $RandomNumber;

# Get SysConfig object.
my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

my $Home       = $Kernel::OM->Get('Kernel::Config')->Get('Home');
my $TargetPath = "$Home/var/tmp/$FileName.yaml";

# Test cases.
my @Tests = (
    {
        Name     => 'No Options',
        Options  => [],
        ExitCode => 1,
    },
    {
        Name     => 'Missing setting-name value',
        Options  => ['--setting-name'],
        ExitCode => 1,
    },
    {
        Name           => 'Missing target-path',
        Options        => [ '--setting-name', $SettingName ],
        NotFileCreated => 1,
        ExitCode       => 0,
    },
    {
        Name     => 'Missing target-path value',
        Options  => [ '--setting-name', $SettingName, '--target-path' ],
        ExitCode => 1,
    },
    {
        Name     => 'Wrong setting-name',
        Options  => [ '--setting-name', 'ANOTVALIDSETTINGNAME', '--target-path', $TargetPath ],
        ExitCode => 1,
    },
    {
        Name     => 'Correct Dump',
        Options  => [ '--setting-name', $SettingName, '--target-path', $TargetPath ],
        ExitCode => 0,
    },
);

# get needed objects
my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::Config::Read');
my $MainObject    = $Kernel::OM->Get('Kernel::System::Main');
my $YAMLObject    = $Kernel::OM->Get('Kernel::System::YAML');

for my $Test (@Tests) {

    my $ExitCode = $CommandObject->Execute( @{ $Test->{Options} } );

    $Self->Is(
        $ExitCode,
        $Test->{ExitCode},
        "$Test->{Name}",
    );

    if ( !$Test->{ExitCode} && !defined $Test->{NotFileCreated} ) {

        my %Setting = $SysConfigObject->SettingGet(
            Name => $SettingName,
        );

        my $ContentSCALARRef = $MainObject->FileRead(
            Location => $TargetPath,
            Mode     => 'utf8',
            Type     => 'Local',
            Result   => 'SCALAR',
        );

        my $Config = $YAMLObject->Load(
            Data => ${$ContentSCALARRef},
        );

        $Self->IsDeeply(
            $Setting{EffectiveValue},
            $Config,
            "$Test->{Name} - effective value config"
        );
    }
}

if ( -e $TargetPath ) {

    my $Success = unlink $TargetPath;

    $Self->True(
        $Success,
        "Deleted temporary file $TargetPath with true",
    );
}

# cleanup is done by RestoreDatabase

$Self->DoneTesting();
