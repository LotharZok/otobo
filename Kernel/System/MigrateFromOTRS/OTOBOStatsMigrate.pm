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

package Kernel::System::MigrateFromOTRS::OTOBOStatsMigrate;

use strict;
use warnings;
use namespace::autoclean;

use parent qw(Kernel::System::MigrateFromOTRS::Base);

# core modules

# CPAN modules

# OTOBO modules

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Cache',
    'Kernel::System::DateTime',
);

=head1 NAME

Kernel::System::MigrateFromOTRS::OTOBOStatsMigrate - Migrate Notification table to OTOBO.

=head1 SYNOPSIS

    # to be called from L<Kernel::Modules::MigrateFromOTRS>.

=head1 PUBLIC INTERFACE

=head2 CheckPreviousRequirement()

check for initial conditions for running this migration step.

Returns 1 on success.

    my $RequirementIsMet = $MigrateFromOTRSObject->CheckPreviousRequirement();

=cut

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 Run()

Execute the migration task. Called by C<Kernel::System::MigrateFromOTRS::_ExecuteRun()>.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # Set cache object with taskinfo and starttime to show current state in frontend
    my $CacheObject    = $Kernel::OM->Get('Kernel::System::Cache');
    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
    my $Epoch          = $DateTimeObject->ToEpoch();

    $CacheObject->Set(
        Type  => 'OTRSMigration',
        Key   => 'MigrationState',
        Value => {
            Task      => 'OTOBOStatsMigrate',
            SubTask   => "Migrate statistics to OTOBO.",
            StartTime => $Epoch,
        },
    );

    my %Result;
    $Result{Message}    = $Self->{LanguageObject}->Translate("Migrate statistics.");
    $Result{Comment}    = $Self->{LanguageObject}->Translate("Migration failed.");
    $Result{Successful} = 0;

    # map wrong to correct tags
    my %StatsTagsOld2New = (
        'otrs_stats' => 'otobo_stats',
    );

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $XMLType = 'Stats';
    return \%Result if !$DBObject->Prepare(
        SQL  => 'SELECT xml_type, xml_key, xml_content_key, xml_content_value FROM xml_storage WHERE xml_type = ?',
        Bind => [ \$XMLType, ],
    );

    # get all stats entries
    my @StatsEntrys;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        push @StatsEntrys, {
            xml_type          => $Row[0],
            xml_key           => $Row[1],
            xml_content_key   => $Row[2],
            xml_content_value => $Row[3],
        };
    }

    STATSENTRY:
    for my $Entry (@StatsEntrys) {

        # remember if we need to replace something
        my $ValueKeyToReplace;

        # get old notification tag
        for my $OldTag ( sort keys %StatsTagsOld2New ) {

            # get new notification tag
            my $NewTag = $StatsTagsOld2New{$OldTag};

            # replace tags in Subject and Text
            ATTRIBUTE:
            for my $Attribute (qw(xml_content_key xml_content_value)) {

                # only if old tags are found
                next ATTRIBUTE if $Entry->{$Attribute} !~ m{$OldTag}xms;

                # remember the key of the replacement
                $ValueKeyToReplace //= $Entry->{xml_content_key};

                # replace the wrong tags
                $Entry->{$Attribute} =~ s{$OldTag}{$NewTag}gxms;
            }
        }

        # only change the database if something has been really replaced
        next STATSENTRY if !$ValueKeyToReplace;

        # update the database
        $DBObject->Do(
            SQL => 'UPDATE xml_storage
                SET xml_content_key = ?, xml_content_value = ?
                WHERE xml_key = ? AND xml_type = ? AND xml_content_key = ?',
            Bind => [
                \$Entry->{xml_content_key},
                \$Entry->{xml_content_value},
                \$Entry->{xml_key},
                \$Entry->{xml_type},
                \$ValueKeyToReplace,
            ],
        );
    }

    $Result{Message}    = $Self->{LanguageObject}->Translate("Migrate statistics.");
    $Result{Comment}    = $Self->{LanguageObject}->Translate("Migration completed, perfect!");
    $Result{Successful} = 1;

    return \%Result;
}

1;
