# =============================================================================
# EventForce - permission set generator
# =============================================================================
# Creates the five EventForce permission sets.
# The custom field list of every object is read from the generated field
# metadata, so the permission sets can never get out of sync with the objects.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-permissionsets.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$base = Join-Path $root 'force-app\main\default'

function XmlEsc([string]$value) {
    if ($null -eq $value) { return '' }
    $value = $value -replace '&', '&amp;'
    $value = $value -replace '<', '&lt;'
    $value = $value -replace '>', '&gt;'
    return $value
}

function Get-CustomFields([string]$objectName) {
    $fieldDir = Join-Path $base ('objects\' + $objectName + '\fields')
    if (-not (Test-Path -LiteralPath $fieldDir)) { return @() }
    $names = Get-ChildItem -LiteralPath $fieldDir -Filter '*.field-meta.xml' |
        ForEach-Object { $_.Name -replace '\.field-meta\.xml$', '' } |
        Where-Object { $_ -ne 'Name' } |
        Sort-Object
    return @($names)
}

$classes = @(
    'EventTriggerHandler', 'VenueStatusHelper', 'PreventDoubleBooking', 'BatchCompleteEvents', 'ScheduleCompleteEvents'
)

$roles = @(
    @{
        id = 'Event_Admin'
        label = 'Event Admin'
        description = 'Full access to the complete EventForce Management System.'
        rights = @{ 'Event__c' = 'CRUD'; 'Client__c' = 'CRUD'; 'Vendor__c' = 'CRUD'; 'Venue__c' = 'CRUD'; 'Feedback__c' = 'CRUD'; 'EventVendor__c' = 'CRUD' }
        viewAll = $true
        classes = $true
        settings = $true
        tabs = @('Event__c', 'Client__c', 'Vendor__c', 'Venue__c', 'Feedback__c', 'standard-reports', 'standard-dashboards')
    }
    @{
        id = 'Event_Coordinator'
        label = 'Event Coordinator'
        description = 'Plans events: create, edit and cancel own events, record feedback, read clients, vendors and venues.'
        rights = @{ 'Event__c' = 'CRUD'; 'EventVendor__c' = 'CRUD'; 'Feedback__c' = 'CRUD'; 'Client__c' = 'R'; 'Vendor__c' = 'R'; 'Venue__c' = 'R' }
        viewAll = $false
        classes = $false
        settings = $false
        tabs = @('Event__c', 'Client__c', 'Vendor__c', 'Venue__c', 'Feedback__c', 'standard-reports', 'standard-dashboards')
    }
    @{
        id = 'Vendor_Manager'
        label = 'Vendor Manager'
        description = 'Maintains vendors and assigns them to events. Read only access to events and venues.'
        rights = @{ 'Vendor__c' = 'CRUD'; 'EventVendor__c' = 'CRUD'; 'Event__c' = 'R'; 'Venue__c' = 'R'; 'Client__c' = 'R' }
        viewAll = $false
        classes = $false
        settings = $false
        tabs = @('Vendor__c', 'Event__c')
    }
    @{
        id = 'Venue_Manager'
        label = 'Venue Manager'
        description = 'Maintains venues and their availability. Read only access to events and vendors.'
        rights = @{ 'Venue__c' = 'CRUD'; 'Event__c' = 'R'; 'Vendor__c' = 'R'; 'Client__c' = 'R' }
        viewAll = $false
        classes = $false
        settings = $false
        tabs = @('Venue__c', 'Event__c')
    }
    @{
        id = 'Client'
        label = 'Client'
        description = 'Client access: read own events, read own client record, give feedback.'
        rights = @{ 'Event__c' = 'R'; 'Client__c' = 'R'; 'Feedback__c' = 'CRU' }
        viewAll = $false
        classes = $false
        settings = $false
        tabs = @('Event__c', 'Feedback__c')
    }
)

$tabDir = Join-Path $base 'permissionsets'
if (-not (Test-Path -LiteralPath $tabDir)) { New-Item -ItemType Directory -Path $tabDir -Force | Out-Null }

foreach ($role in $roles) {
    $b = New-Object System.Text.StringBuilder
    [void]$b.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$b.AppendLine('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">')

    if ($role.classes) {
        [void]$b.AppendLine('    <classAccesses>')
        foreach ($class in $classes) {
            [void]$b.AppendLine("        <apexClass>$class</apexClass>")
            [void]$b.AppendLine('        <enabled>true</enabled>')
        }
        [void]$b.AppendLine('    </classAccesses>')
    }

    if ($role.settings) {
        [void]$b.AppendLine('    <customSettingAccesses>')
        [void]$b.AppendLine('        <enabledSetting>EventForce_Schedule__c</enabledSetting>')
        [void]$b.AppendLine('    </customSettingAccesses>')
    }

    [void]$b.AppendLine('    <description>' + (XmlEsc $role.description) + '</description>')

    [void]$b.AppendLine('    <fieldPermissions>')
    foreach ($objectName in ($role.rights.Keys | Sort-Object)) {
        $rights = $role.rights[$objectName]
        $editable = $rights.Contains('U') -or $rights.Contains('C')
        foreach ($fieldName in (Get-CustomFields $objectName)) {
            [void]$b.AppendLine('        <field>' + $objectName + '.' + $fieldName + '</field>')
            [void]$b.AppendLine('        <editable>' + $(if ($editable) { 'true' } else { 'false' }) + '</editable>')
            [void]$b.AppendLine('        <readable>true</readable>')
        }
    }
    [void]$b.AppendLine('    </fieldPermissions>')

    [void]$b.AppendLine('    <hasActivationRequired>false</hasActivationRequired>')
    [void]$b.AppendLine('    <label>' + (XmlEsc $role.label) + '</label>')

    [void]$b.AppendLine('    <objectPermissions>')
    foreach ($objectName in ($role.rights.Keys | Sort-Object)) {
        $rights = $role.rights[$objectName]
        [void]$b.AppendLine('        <allowCreate>' + $rights.Contains('C').ToString().ToLower() + '</allowCreate>')
        [void]$b.AppendLine('        <allowDelete>' + $rights.Contains('D').ToString().ToLower() + '</allowDelete>')
        [void]$b.AppendLine('        <allowEdit>' + $rights.Contains('U').ToString().ToLower() + '</allowEdit>')
        [void]$b.AppendLine('        <allowRead>true</allowRead>')
        [void]$b.AppendLine('        <modifyAllRecords>false</modifyAllRecords>')
        [void]$b.AppendLine('        <object>' + $objectName + '</object>')
        [void]$b.AppendLine('        <viewAllRecords>' + $(if ($role.viewAll) { 'true' } else { 'false' }) + '</viewAllRecords>')
    }
    [void]$b.AppendLine('    </objectPermissions>')

    [void]$b.AppendLine('    <tabSettings>')
    foreach ($tab in $role.tabs) {
        [void]$b.AppendLine('        <tab>' + $tab + '</tab>')
        [void]$b.AppendLine('        <visibility>Visible</visibility>')
    }
    [void]$b.AppendLine('    </tabSettings>')

    [void]$b.AppendLine('</PermissionSet>')

    $path = Join-Path $tabDir ($role.id + '.permissionset-meta.xml')
    Set-Content -LiteralPath $path -Value $b.ToString() -Encoding UTF8
    Write-Host ("Permission set {0,-18} -> {1} objects" -f $role.id, $role.rights.Count)
}

Write-Host "`nEventForce: permission sets written to $tabDir"
