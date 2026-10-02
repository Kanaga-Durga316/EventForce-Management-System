# =============================================================================
# EventForce - package.xml generator
# =============================================================================
# Builds manifest/package.xml from the files that are actually present in
# force-app, so the manifest can never be out of sync with the source.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-package-xml.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$default = Join-Path $root 'force-app\main\default'
$packageDir = Join-Path $root 'manifest'

$map = [ordered]@{
    'CustomObject'      = @{ Path = 'objects'; Pattern = '*.object-meta.xml' }
    'CustomField'       = @{ Path = 'objects'; Pattern = '*.field-meta.xml' }
    'ValidationRule'    = @{ Path = 'objects'; Pattern = '*.validationRule-meta.xml' }
    'ApexClass'         = @{ Path = 'classes'; Pattern = '*.cls' }
    'ApexTrigger'       = @{ Path = 'triggers'; Pattern = '*.trigger' }
    'Flow'              = @{ Path = 'flows'; Pattern = '*.flow-meta.xml' }
    'ApprovalProcess'   = @{ Path = 'approvalProcesses'; Pattern = '*.approvalProcess-meta.xml' }
    'CustomPermissionSet' = @{ Path = 'permissionsets'; Pattern = '*.permissionset-meta.xml' }
    'SharingRule'       = @{ Path = 'sharingRules'; Pattern = '*.sharingRule-meta.xml' }
    'CustomTab'         = @{ Path = 'tabs'; Pattern = '*.tab-meta.xml' }
    'CustomApplication' = @{ Path = 'applications'; Pattern = '*.app-meta.xml' }
    'CustomSettings'    = @{ Path = 'customSettings'; Pattern = '*.settings-meta.xml' }
    'Report'            = @{ Path = 'reports'; Pattern = '*.report-meta.xml' }
    'Dashboard'         = @{ Path = 'dashboards'; Pattern = '*.dashboard-meta.xml' }
}

$types = New-Object System.Collections.Generic.List[string]

foreach ($typeName in $map.Keys) {
    $definition = $map[$typeName]
    $members = New-Object System.Collections.Generic.List[string]

    $root_ = Join-Path $default $definition.Path
    if (Test-Path -LiteralPath $root_) {
        $files = Get-ChildItem -LiteralPath $root_ -Recurse -Filter $definition.Pattern -File
        foreach ($file in $files) {
            $name = $file.Name
            $relativeDir = $file.DirectoryName.Substring($root_.Length).TrimStart('\')

            if ($typeName -eq 'CustomObject') {
                $members.Add(($name -replace '\.object-meta\.xml$', ''))
            }
            elseif ($typeName -eq 'CustomField' -or $typeName -eq 'ValidationRule') {
                $objectName = ($relativeDir -split '\\')[0]
                $member = $name -replace '\.field-meta\.xml$', ''
                $member = $member -replace '\.validationRule-meta\.xml$', ''
                if ($member -eq 'Name') { continue }
                $members.Add(($objectName + '.' + $member))
            }
            elseif ($typeName -eq 'Report' -or $typeName -eq 'Dashboard') {
                $members.Add(($name -replace '\.report-meta\.xml$', '' -replace '\.dashboard-meta\.xml$', ''))
            }
            elseif ($typeName -eq 'CustomSettings') {
                $members.Add(($name -replace '\.settings-meta\.xml$', ''))
            }
            else {
                $member = $name
                foreach ($suffix in @('.cls', '.trigger', '.flow-meta.xml', '.approvalProcess-meta.xml', '.permissionset-meta.xml', '.sharingRule-meta.xml', '.tab-meta.xml', '.app-meta.xml')) {
                    $member = $member -replace ([regex]::Escape($suffix) + '$'), ''
                }
                $members.Add($member)
            }
        }
    }

    if ($members.Count -eq 0) { continue }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('        <members>' + (($members | Sort-Object) -join '</members>' + '<members>') + '</members>')
    $block = "    <types>`n" + ($lines -join "`n") + "`n        <name>$typeName</name>`n    </types>"
    $types.Add($block)
    Write-Host ("{0,-20} {1,3} components" -f $typeName, $members.Count)
}

if (-not (Test-Path -LiteralPath $packageDir)) { New-Item -ItemType Directory -Path $packageDir -Force | Out-Null }
$packagePath = Join-Path $packageDir 'package.xml'
$xml = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
) + $types + @(
    '    <version>62.0</version>'
    '</Package>'
)
Set-Content -LiteralPath $packagePath -Value ($xml -join "`r`n") -Encoding UTF8

Write-Host "`nEventForce: manifest written to $packagePath"
