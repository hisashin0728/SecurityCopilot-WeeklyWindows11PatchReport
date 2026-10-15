[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$TenantId,

    [string]$OutputPath = (Join-Path $PSScriptRoot 'WeeklyWindows11PatchReport.local.yaml')
)

$ErrorActionPreference = 'Stop'

if ([guid]$TenantId -eq [guid]::Empty) {
    throw 'TenantId must be a non-empty Directory (tenant) ID.'
}

$templatePath = Join-Path $PSScriptRoot 'WeeklyWindows11PatchReport.yaml'
$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ($resolvedOutputPath -eq $templatePath) {
    throw 'OutputPath must not overwrite the shared template.'
}

$template = [System.IO.File]::ReadAllText($templatePath)
$placeholder = '<YOUR-TENANT-ID>'
if ([regex]::Matches($template, [regex]::Escape($placeholder)).Count -ne 1) {
    throw 'The template must contain exactly one Tenant ID placeholder.'
}

$manifest = $template.Replace($placeholder, ([guid]$TenantId).ToString())
$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($manifest)
$stream = [System.IO.File]::Open($resolvedOutputPath, [System.IO.FileMode]::CreateNew)
try {
    $stream.Write($bytes, 0, $bytes.Length)
}
finally {
    $stream.Dispose()
}

Write-Output "Upload this generated manifest to Security Copilot: $resolvedOutputPath"
