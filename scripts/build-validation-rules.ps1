# =============================================================================
# EventForce - validation rule generator
# =============================================================================
# Writes every validation rule of the EventForce Management System.
# The metadata format requires the root element <ValidationRule> and the child
# elements in alphabetical order.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-validation-rules.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$base = Join-Path $root 'force-app\main\default\objects'

function XmlEsc([string]$value) {
    if ($null -eq $value) { return '' }
    $value = $value -replace '&', '&amp;'
    $value = $value -replace '<', '&lt;'
    $value = $value -replace '>', '&gt;'
    return $value
}

function Write-ValidationRule($ObjectName, $Name, $Description, $Formula, $DisplayField, $Message) {
    $dir = Join-Path $base ($ObjectName + '\validationRules')
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $xml = @(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">'
        '    <active>true</active>'
        ('    <description>' + (XmlEsc $Description) + '</description>')
        ('    <errorConditionFormula>' + (XmlEsc $Formula) + '</errorConditionFormula>')
        ('    <errorDisplayField>' + (XmlEsc $DisplayField) + '</errorDisplayField>')
        ('    <errorMessage>' + (XmlEsc $Message) + '</errorMessage>')
        ('    <fullName>' + $Name + '</fullName>')
        '</ValidationRule>'
    ) -join "`r`n"
    $path = Join-Path $dir ($Name + '.validationRule-meta.xml')
    Set-Content -LiteralPath $path -Value $xml -Encoding UTF8
    Write-Host ("Validation rule {0}.{1}" -f $ObjectName, $Name)
}

# ---------------------------------------------------------------- Event__c ---
Write-ValidationRule 'Event__c' 'Event_Date_Required' `
    'The date of the event is mandatory - it drives the double booking check and the client reminder.' `
    'ISBLANK(Event_Date__c)' `
    'Event__c.Event_Date__c' `
    'Enter the date of the event.'

Write-ValidationRule 'Event__c' 'End_Date_After_Start_Date' `
    'The end date of an event cannot be before its start date.' `
    'AND(NOT(ISBLANK(Start_Date__c)), NOT(ISBLANK(End_Date__c)), End_Date__c < Start_Date__c)' `
    'Event__c.End_Date__c' `
    'The end date of the event must be on or after the start date.'

Write-ValidationRule 'Event__c' 'Client_Required' `
    'Every event must be linked to a client.' `
    'ISBLANK(Client__c)' `
    'Event__c.Client__c' `
    'Select the client this event is organised for.'

Write-ValidationRule 'Event__c' 'Venue_Required_When_Confirmed' `
    'A venue is mandatory as soon as the event is confirmed, because the venue is booked automatically.' `
    'AND(ISPICKVAL(Status__c, "Confirmed"), ISBLANK(Venue__c))' `
    'Event__c.Venue__c' `
    'Select a venue before confirming the event. A confirmed event always holds a venue.'

Write-ValidationRule 'Event__c' 'Event_Date_Not_In_Past_For_Confirmed' `
    'An event can only be confirmed for today or a future date. Past events keep their data so that BatchCompleteEvents can still complete them.' `
    'AND(ISPICKVAL(Status__c, "Confirmed"), NOT(ISBLANK(Event_Date__c)), Event_Date__c < TODAY(), OR(ISNEW(), ISCHANGED(Event_Date__c)))' `
    'Event__c.Event_Date__c' `
    'A confirmed event cannot have a date in the past. Select today or a future date.'

Write-ValidationRule 'Event__c' 'Cancellation_Requires_Approval' `
    'An event can only be cancelled through the Event Cancellation Approval process.' `
    'AND(ISPICKVAL(Status__c, "Cancelled"), NOT(ISPICKVAL(PRIORVALUE(Status__c), "Pending Cancellation")))' `
    'Event__c.Status__c' `
    'An event cannot be cancelled directly. Set the status to Pending Cancellation and submit the record for approval.'

Write-ValidationRule 'Event__c' 'Cancellation_Reason_Required' `
    'A cancelled event must always carry a cancellation reason.' `
    'AND(ISPICKVAL(Status__c, "Cancelled"), ISBLANK(Cancellation_Reason__c))' `
    'Event__c.Cancellation_Reason__c' `
    'A cancelled event requires a cancellation reason. Complete the field before saving.'

# ---------------------------------------------------------------- Venue__c ---
Write-ValidationRule 'Venue__c' 'Capacity_Must_Be_Positive' `
    'A venue must be able to host at least one person.' `
    'AND(NOT(ISBLANK(Capacity__c)), Capacity__c < 1)' `
    'Venue__c.Capacity__c' `
    'The capacity of a venue must be at least 1.'

# ------------------------------------------------------------- Feedback__c ---
Write-ValidationRule 'Feedback__c' 'Feedback_Event_Required' `
    'Feedback without an event has no meaning.' `
    'ISBLANK(Event__c)' `
    'Feedback__c.Event__c' `
    'Select the event this feedback belongs to.'

Write-ValidationRule 'Feedback__c' 'Feedback_Rating_Range' `
    'The feedback rating is a score between 0 and 5.' `
    'AND(NOT(ISBLANK(Rating__c)), OR(Rating__c < 0, Rating__c > 5))' `
    'Feedback__c.Rating__c' `
    'The rating must be a score between 0 and 5.'

Write-ValidationRule 'Feedback__c' 'Feedback_For_Upcoming_Events_Only' `
    'Feedback is collected for current and future events only.' `
    'AND(ISNEW(), NOT(ISBLANK(Event_Date__c)), Event_Date__c < TODAY())' `
    'Feedback__c.Event__c' `
    'Feedback can only be recorded for an event that has not taken place yet.'

Write-ValidationRule 'Feedback__c' 'Feedback_Client_Must_Match_Event' `
    'Feedback must be given by the client of the related event.' `
    'AND(NOT(ISBLANK(Client__c)), NOT(ISBLANK(Event__r.Client__c)), Client__c <> Event__r.Client__c)' `
    'Feedback__c.Client__c' `
    'Feedback can only be given by the client of the related event.'

Write-Host "`nEventForce: all validation rules written to $base"
