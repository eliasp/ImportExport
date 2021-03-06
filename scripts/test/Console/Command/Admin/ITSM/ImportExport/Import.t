# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));
use File::Path qw(rmtree);

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::ITSM::ImportExport::Import');
my $HelperObject  = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# test command without --template-number option
my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "No --template-number  - exit code",
);

# get ImportExport object
my $ImportExportObject = $Kernel::OM->Get('Kernel::System::ImportExport');

# add test template
my $TemplateID = $ImportExportObject->TemplateAdd(
    Object  => 'ITSMConfigItem',
    Format  => 'CSV',
    Name    => 'Template' . $HelperObject->GetRandomID(),
    ValidID => 1,
    Comment => 'Comment',                                   # (optional)
    UserID  => 1,
);

$Self->True(
    $TemplateID,
    "Import/Export template is created - $TemplateID",
);

# get general catalog object
my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

# get 'Hardware' catalog class ID
my $ConfigItemDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Hardware',
);
my $HardwareConfigItemID = $ConfigItemDataRef->{ItemID};

# get object data for test template
my %TemplateRef = (
    'ClassID'  => $HardwareConfigItemID,
    'CountMax' => 10,
);
my $Success = $ImportExportObject->ObjectDataSave(
    TemplateID => $TemplateID,
    ObjectData => \%TemplateRef,
    UserID     => 1,
);

$Self->True(
    $Success,
    "ObjectData for test template is added",
);

# add the format data of the test template
my %FormatData = (
    Charset              => 'UTF-8',
    ColumnSeparator      => 'Comma',
    IncludeColumnHeaders => 1,
);
$Success = $ImportExportObject->FormatDataSave(
    TemplateID => $TemplateID,
    FormatData => \%FormatData,
    UserID     => 1,
);

$Self->True(
    $Success,
    "FormatData for test template is added",
);

# save the search data of a template
my %SearchData = (
    Name => 'TestConfigItem*',
);
$Success = $ImportExportObject->SearchDataSave(
    TemplateID => $TemplateID,
    SearchData => \%SearchData,
    UserID     => 1,
);

# add mapping data for test template
for my $ObjectDataValue (qw( Name DeplState InciState )) {

    my $MappingID = $ImportExportObject->MappingAdd(
        TemplateID => $TemplateID,
        UserID     => 1,
    );

    my %MappingObjectData = ( Key => $ObjectDataValue );
    my $Success = $ImportExportObject->MappingObjectDataSave(
        MappingID         => $MappingID,
        MappingObjectData => \%MappingObjectData,
        UserID            => 1,
    );

    $Self->True(
        $Success,
        "ObjectData for test template is mapped - $ObjectDataValue",
    );
}

# make directory for export file
my $SourcePath
    = $Kernel::OM->Get('Kernel::Config')->Get('Home') . "/scripts/test/sample/ImportExport/TemplateExport.csv";

# test command with wrong template number
$ExitCode
    = $CommandObject->Execute( '--template-number', $HelperObject->GetRandomID(), $SourcePath . 'TemplateExport.csv' );

$Self->Is(
    $ExitCode,
    1,
    "Command with wrong template number - exit code",
);

# test command without Source argument
$ExitCode = $CommandObject->Execute( '--template-number', $TemplateID );

$Self->Is(
    $ExitCode,
    1,
    "No Source argument - exit code",
);

# test command with --template-number option and Source argument
$ExitCode = $CommandObject->Execute( '--template-number', $TemplateID, $SourcePath );

$Self->Is(
    $ExitCode,
    0,
    "Option - --template-number option and Source argument",
);

# get config item object
my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
my $ConfigItemIDs    = $ConfigItemObject->ConfigItemSearchExtended(
    Name => 'TestConfigItem*'
);
my $NumConfigItemImported = scalar @{$ConfigItemIDs};

# check if the config items are imported
$Self->True(
    $NumConfigItemImported,
    "There are $NumConfigItemImported imported config items",
);

# clean up test data
# delete test template
$Success = $ImportExportObject->TemplateDelete(
    TemplateID => $TemplateID,
    UserID     => 1,
);

$Self->True(
    $Success,
    "Test template is deleted - $TemplateID",
);

# delete test config items
for my $ConfigItemID ( @{$ConfigItemIDs} ) {
    my $Success = $ConfigItemObject->ConfigItemDelete(
        ConfigItemID => $ConfigItemID,
        UserID       => 1,
    );
    $Self->True(
        $Success,
        "Configitem is deleted - $ConfigItemID",
    );
}

1;
