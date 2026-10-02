# =============================================================================
# EventForce - metadata generator (objects + fields)
# =============================================================================
# Creates every CustomObject and CustomField metadata file of the EventForce
# Management System under force-app/main/default/objects/.
#
# The script is deterministic: running it again simply rewrites the same files.
# It is the single place where the field API names of the project are defined.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-objects.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$base = Join-Path $root 'force-app\main\default\objects'

function XmlEsc([string]$value) {
    if ($null -eq $value) { return '' }
    $value = $value -replace '&', '&amp;'
    $value = $value -replace '<', '&lt;'
    $value = $value -replace '>', '&gt;'
    $value = $value -replace '"', '&quot;'
    return $value
}

function New-FieldXml($Spec) {
    $b = New-Object System.Text.StringBuilder
    function Elem([string]$name, $value) {
        if ($null -ne $value) { [void]$b.AppendLine("    <$name>" + (XmlEsc ([string]$value)) + "</$name>") }
    }
    function Flag([string]$name, [bool]$value) {
        [void]$b.AppendLine("    <$name>" + $(if ($value) { 'true' } else { 'false' }) + "</$name>")
    }

    [void]$b.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$b.AppendLine('<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">')
    Elem 'fullName' $Spec.f

    switch ($Spec.k) {

        'nameText' {
            Elem 'label' $Spec.label
            Elem 'length' $Spec.len
            Flag 'required' $true
            Elem 'type' 'Text'
            Flag 'unique' $false
        }

        'picklist' {
            Elem 'defaultValue' $Spec.def
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            [void]$b.AppendLine('    <picklistValues>')
            foreach ($v in $Spec.values) { [void]$b.AppendLine("        <picklistValue>" + (XmlEsc $v) + '</picklistValue>') }
            [void]$b.AppendLine('    </picklistValues>')
            Flag 'restrictedPicklist' ([bool]$Spec.restricted)
            Elem 'type' 'Picklist'
        }

        'date' {
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            Flag 'required' ([bool]$Spec.required)
            Elem 'type' 'Date'
        }

        'number' {
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            Elem 'precision' $Spec.precision
            Elem 'scale' $Spec.scale
            Elem 'type' 'Number'
        }

        'currency' {
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            Elem 'precision' $Spec.precision
            Elem 'scale' $Spec.scale
            Elem 'type' 'Currency'
        }

        'text' {
            Elem 'description' $Spec.description
            if ($Spec.externalId) { Flag 'externalId' $true }
            Elem 'label' $Spec.label
            Elem 'length' $Spec.len
            Elem 'type' 'Text'
            Flag 'unique' ([bool]$Spec.unique)
        }

        'textarea' {
            Elem 'label' $Spec.label
            Elem 'length' $Spec.len
            Elem 'type' 'TextArea'
        }

        'longtextarea' {
            Elem 'label' $Spec.label
            Elem 'length' $Spec.len
            Elem 'type' 'LongTextArea'
        }

        'email' {
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            Elem 'type' 'Email'
        }

        'phone' {
            Elem 'label' $Spec.label
            Elem 'type' 'Phone'
        }

        'lookup' {
            Elem 'description' $Spec.description
            Elem 'label' $Spec.label
            Elem 'referenceTo' $Spec.ref
            Elem 'relationshipLabel' $Spec.relationshipLabel
            Elem 'relationshipName' $Spec.relationshipName
            Elem 'type' 'Lookup'
        }

        'masterDetail' {
            Elem 'label' $Spec.label
            Elem 'relationshipLabel' $Spec.relationshipLabel
            Elem 'relationshipName' $Spec.relationshipName
            Elem 'type' 'MasterDetail'
        }

        'numberFormula' {
            Elem 'description' $Spec.description
            Elem 'formula' $Spec.formula
            Elem 'formulaTreatBlanksAs' 'BlankAsZero'
            Elem 'label' $Spec.label
            Elem 'precision' $Spec.precision
            Elem 'scale' $Spec.scale
            Elem 'type' 'Number'
        }

        'textFormula' {
            Elem 'description' $Spec.description
            Elem 'formula' $Spec.formula
            Elem 'formulaTreatBlanksAs' 'BlankAsZero'
            Elem 'label' $Spec.label
            Elem 'length' $Spec.len
            Elem 'type' 'Text'
        }

        'emailFormula' {
            Elem 'description' $Spec.description
            Elem 'formula' $Spec.formula
            Elem 'formulaTreatBlanksAs' 'BlankAsZero'
            Elem 'label' $Spec.label
            Elem 'type' 'Email'
        }

        'dateFormula' {
            Elem 'description' $Spec.description
            Elem 'formula' $Spec.formula
            Elem 'formulaTreatBlanksAs' 'BlankAsZero'
            Elem 'label' $Spec.label
            Elem 'type' 'Date'
        }

        'checkboxFormula' {
            Elem 'description' $Spec.description
            Elem 'formula' $Spec.formula
            Elem 'label' $Spec.label
            Elem 'type' 'Checkbox'
        }

        default { throw "Unknown field kind $($Spec.k) for $($Spec.f)" }
    }

    [void]$b.AppendLine('</CustomField>')
    return $b.ToString()
}

function New-ObjectXml($Object) {
    $b = New-Object System.Text.StringBuilder
    [void]$b.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$b.AppendLine('<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">')
    [void]$b.AppendLine('    <deploymentStatus>Deployed</deploymentStatus>')
    [void]$b.AppendLine('    <description>' + (XmlEsc $Object.description) + '</description>')
    [void]$b.AppendLine('    <enableActivities>' + $(if ($Object.activities) { 'true' } else { 'false' }) + '</enableActivities>')
    [void]$b.AppendLine('    <enableHistory>false</enableHistory>')
    [void]$b.AppendLine('    <enableReports>true</enableReports>')
    [void]$b.AppendLine('    <enableSearch>true</enableSearch>')
    [void]$b.AppendLine('    <enableSharing>true</enableSharing>')
    [void]$b.AppendLine('    <label>' + (XmlEsc $Object.label) + '</label>')
    [void]$b.AppendLine('    <labelPlural>' + (XmlEsc $Object.plural) + '</labelPlural>')
    [void]$b.AppendLine('    <nameField>')
    [void]$b.AppendLine('        <label>' + (XmlEsc $Object.nameLabel) + '</label>')
    [void]$b.AppendLine('        <length>80</length>')
    [void]$b.AppendLine('        <required>true</required>')
    [void]$b.AppendLine('        <type>Text</type>')
    [void]$b.AppendLine('        <unique>false</unique>')
    [void]$b.AppendLine('    </nameField>')
    [void]$b.AppendLine('    <sharingModel>' + $Object.sharing + '</sharingModel>')
    [void]$b.AppendLine('    <visibility>Public</visibility>')
    [void]$b.AppendLine('</CustomObject>')
    return $b.ToString()
}

# =============================================================================
# Field definitions - THE single source of truth for the API names
# =============================================================================
$objects = @(

    @{
        name = 'Event__c'; label = 'Event'; plural = 'Events'; nameLabel = 'Event Name'
        sharing = 'Private'; activities = $true
        description = 'EventForce event record. Owns the event planning process, the client and the venue booking.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Event Name' }
            @{ k = 'picklist'; f = 'Status__c'; label = 'Status'; def = 'Draft'; restricted = $true
               description = 'Planning status of the event. Draft > Pending Cancellation > Confirmed > Cancelled / Completed.'
               values = @('Draft', 'Pending Cancellation', 'Confirmed', 'Cancelled', 'Completed') }
            @{ k = 'date'; f = 'Event_Date__c'; label = 'Event Date'; required = $true
               description = 'Date of the event. Used for the double booking check and for the client reminder.' }
            @{ k = 'date'; f = 'Start_Date__c'; label = 'Start Date'
               description = 'First day of the event, used to calculate the duration.' }
            @{ k = 'date'; f = 'End_Date__c'; label = 'End Date'
               description = 'Last day of the event, used to calculate the duration.' }
            @{ k = 'lookup'; f = 'Client__c'; label = 'Client'; ref = 'Client__c'
               relationshipLabel = 'Events'; relationshipName = 'Events'
               description = 'Client the event is organised for.' }
            @{ k = 'lookup'; f = 'Venue__c'; label = 'Venue'; ref = 'Venue__c'
               relationshipLabel = 'Events'; relationshipName = 'Events'
               description = 'Venue booked for the event. The venue is marked as Booked when the event is confirmed.' }
            @{ k = 'textarea'; f = 'Cancellation_Reason__c'; label = 'Cancellation Reason'
               description = 'Mandatory when the event is cancelled.' }
            @{ k = 'longtextarea'; f = 'Cancellation_Comments__c'; label = 'Cancellation Comments'
               description = 'Extra information stored when a cancellation is approved.' }
            @{ k = 'email'; f = 'Vendor_Contact_Email__c'; label = 'Vendor Contact Email'
               description = 'Email of the vendor contact that is allowed to see this event (Event_Sharing_For_Vendors).' }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
            @{ k = 'emailFormula'; f = 'Client_Email__c'; label = 'Client Email'
               formula = 'Client__r.Email__c'
               description = 'Email of the client, used as the recipient of the client reminder.' }
            @{ k = 'numberFormula'; f = 'Duration_Days__c'; label = 'Duration (Days)'; precision = 0; scale = 0
               formula = 'IF(OR(ISBLANK(Start_Date__c),ISBLANK(End_Date__c)),0,End_Date__c - Start_Date__c + 1)'
               description = 'Number of days the event lasts. 0 when start or end date is not set.' }
            @{ k = 'textFormula'; f = 'Event_Month__c'; label = 'Event Month'; len = 255
               formula = 'TEXT(YEAR(Event_Date__c))&"-"&RIGHT("0"&TEXT(MONTH(Event_Date__c)),2)'
               description = 'Year and month of the event date (YYYY-MM), used to group the Upcoming Events by Month report.' }
            @{ k = 'numberFormula'; f = 'Event_Days_Until__c'; label = 'Days Until Event'; precision = 4; scale = 0
               formula = 'IF(ISBLANK(Event_Date__c),0,Event_Date__c - TODAY())'
               description = 'Number of days between today and the event date. Negative for past events.' }
            @{ k = 'checkboxFormula'; f = 'Is_Upcoming__c'; label = 'Upcoming Event'
               formula = 'IF(ISBLANK(Event_Date__c),FALSE(),TODAY() <= Event_Date__c)'
               description = 'TRUE for current and future events. Used as filter of the client reminder flow.' }
            @{ k = 'textFormula'; f = 'Status_Indicator__c'; label = 'Status Indicator'; len = 255
               formula = 'CASE(Status__c,"Draft","DRAFT - PLANNING","Pending Cancellation","CANCELLATION PENDING APPROVAL","Confirmed","CONFIRMED","Cancelled","CANCELLED","Completed","COMPLETED","UNKNOWN")'
               description = 'Read only indicator of the event status, used on dashboards and list views.' }
        )
    }

    @{
        name = 'Client__c'; label = 'Client'; plural = 'Clients'; nameLabel = 'Client Name'
        sharing = 'ReadWrite'; activities = $true
        description = 'Company or person the events are organised for.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Client Name' }
            @{ k = 'email'; f = 'Email__c'; label = 'Email'; description = 'Recipient of the client reminder.' }
            @{ k = 'phone'; f = 'Phone__c'; label = 'Phone' }
            @{ k = 'text'; f = 'Company__c'; label = 'Company'; len = 80 }
            @{ k = 'text'; f = 'City__c'; label = 'City'; len = 80 }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
        )
    }

    @{
        name = 'Vendor__c'; label = 'Vendor'; plural = 'Vendors'; nameLabel = 'Vendor Name'
        sharing = 'ReadWrite'; activities = $true
        description = 'Service provider that can be assigned to an event through EventVendor__c.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Vendor Name' }
            @{ k = 'email'; f = 'Contact_Email__c'; label = 'Contact Email' }
            @{ k = 'phone'; f = 'Phone__c'; label = 'Phone' }
            @{ k = 'picklist'; f = 'Category__c'; label = 'Category'; def = 'Other'
               values = @('Catering', 'Audio Visual', 'Decor', 'Photography', 'Security', 'Transport', 'Other') }
            @{ k = 'number'; f = 'Rating__c'; label = 'Rating'; precision = 2; scale = 1
               description = 'Quality rating from 0.0 to 5.0.' }
            @{ k = 'picklist'; f = 'Status__c'; label = 'Status'; def = 'Active'
               values = @('Active', 'Inactive') }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
        )
    }

    @{
        name = 'Venue__c'; label = 'Venue'; plural = 'Venues'; nameLabel = 'Venue Name'
        sharing = 'ReadWrite'; activities = $true
        description = 'Physical location of an event. Availability is maintained by VenueStatusHelper.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Venue Name' }
            @{ k = 'picklist'; f = 'Status__c'; label = 'Status'; def = 'Available'
               description = 'Maintained automatically: Booked while a confirmed event uses the venue, Available otherwise.'
               values = @('Available', 'Booked', 'Under Maintenance') }
            @{ k = 'text'; f = 'City__c'; label = 'City'; len = 80 }
            @{ k = 'number'; f = 'Capacity__c'; label = 'Capacity'; precision = 6; scale = 0 }
            @{ k = 'textarea'; f = 'Address__c'; label = 'Address'; len = 255 }
            @{ k = 'email'; f = 'Contact_Email__c'; label = 'Contact Email' }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
        )
    }

    @{
        name = 'Feedback__c'; label = 'Feedback'; plural = 'Feedback'; nameLabel = 'Feedback Reference'
        sharing = 'ReadWrite'; activities = $false
        description = 'Feedback collected from a client for an event.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Feedback Reference' }
            @{ k = 'lookup'; f = 'Event__c'; label = 'Event'; ref = 'Event__c'
               relationshipLabel = 'Feedback'; relationshipName = 'Feedback'
               description = 'Event the feedback belongs to.' }
            @{ k = 'lookup'; f = 'Client__c'; label = 'Client'; ref = 'Client__c'
               relationshipLabel = 'Feedback'; relationshipName = 'Feedback'
               description = 'Client that gave the feedback. Must match the client of the event.' }
            @{ k = 'number'; f = 'Rating__c'; label = 'Rating'; precision = 3; scale = 0
               description = 'Feedback score from 0 to 5.' }
            @{ k = 'longtextarea'; f = 'Comments__c'; label = 'Comments'; len = 1000 }
            @{ k = 'date'; f = 'Submitted_Date__c'; label = 'Submitted Date' }
            @{ k = 'dateFormula'; f = 'Event_Date__c'; label = 'Event Date'
               formula = 'Event__r.Event_Date__c'
               description = 'Date of the related event, used to block feedback for past events.' }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
        )
    }

    @{
        name = 'EventVendor__c'; label = 'Event Vendor'; plural = 'Event Vendors'; nameLabel = 'Assignment'
        sharing = 'ReadWrite'; activities = $false
        description = 'Assignment of a Vendor__c to an Event__c.'
        fields = @(
            @{ k = 'nameText'; f = 'Name'; label = 'Assignment' }
            @{ k = 'masterDetail'; f = 'Event__c'; label = 'Event'
               relationshipLabel = 'Event Vendors'; relationshipName = 'EventVendors' }
            @{ k = 'lookup'; f = 'Vendor__c'; label = 'Vendor'; ref = 'Vendor__c'
               relationshipLabel = 'Event Vendors'; relationshipName = 'EventVendors'
               description = 'Salesforce allows only one master-detail relationship per object, therefore the vendor is a lookup. See the deployment guide.' }
            @{ k = 'textarea'; f = 'Role__c'; label = 'Role'; len = 255
               description = 'Responsibility of the vendor for this event.' }
            @{ k = 'currency'; f = 'Fee__c'; label = 'Fee'; precision = 18; scale = 2 }
            @{ k = 'picklist'; f = 'Assignment_Status__c'; label = 'Assignment Status'; def = 'Requested'
               values = @('Requested', 'Confirmed', 'Completed') }
            @{ k = 'text'; f = 'External_ID__c'; label = 'External ID'; len = 255; externalId = $true; unique = $false
               description = 'External key used by the data import wizard to prevent duplicates.' }
        )
    }
)

# =============================================================================
# Write the files
# =============================================================================
$fieldCount = 0
foreach ($object in $objects) {
    $objectDir = Join-Path $base $object.name
    $fieldDir = Join-Path $objectDir 'fields'
    if (-not (Test-Path -LiteralPath $fieldDir)) {
        New-Item -ItemType Directory -Path $fieldDir -Force | Out-Null
    }

    $objectPath = Join-Path $objectDir ($object.name + '.object-meta.xml')
    Set-Content -LiteralPath $objectPath -Value (New-ObjectXml $object) -Encoding UTF8

    foreach ($field in $object.fields) {
        if ($field.f -eq 'Name') { continue }   # the name field is part of <nameField> in the object metadata
        $fieldPath = Join-Path $fieldDir ($field.f + '.field-meta.xml')
        Set-Content -LiteralPath $fieldPath -Value (New-FieldXml $field) -Encoding UTF8
        $fieldCount++
    }
    Write-Host ("Object {0,-16} -> {1} fields" -f $object.name, ($object.fields.Count - 1))
}

Write-Host ("`nEventForce: {0} objects and {1} custom fields written to {2}" -f $objects.Count, $fieldCount, $base)
