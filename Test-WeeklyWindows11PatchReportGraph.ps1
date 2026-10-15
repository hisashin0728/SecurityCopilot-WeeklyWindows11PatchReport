#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClientId
)

$ErrorActionPreference = 'Stop'
if ([guid]$TenantId -eq [guid]::Empty -or [guid]$ClientId -eq [guid]::Empty) {
    throw 'TenantId and ClientId must be non-empty GUIDs.'
}

$secret = Read-Host 'Enter the Client Secret VALUE (input is hidden; do not share it)' -AsSecureString
if ($secret.Length -eq 0) {
    throw 'Client Secret must not be empty.'
}

$form = @{
    grant_type = 'client_credentials'
    client_id = $ClientId
    client_secret = ConvertFrom-SecureString $secret -AsPlainText
    scope = 'https://graph.microsoft.com/.default'
}
try {
    $tokenResponse = Invoke-WebRequest `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method Post -Body $form -ContentType 'application/x-www-form-urlencoded' `
        -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 60
}
finally {
    $form.Clear()
    $secret.Dispose()
}

$tokenContentType = $tokenResponse.Headers['Content-Type'] -join ','
if ($tokenContentType -notmatch 'application/json') {
    throw "Token endpoint returned a non-JSON response: HTTP $($tokenResponse.StatusCode); Content-Type: $tokenContentType"
}
if ($tokenResponse.StatusCode -ne 200) {
    $details = $tokenResponse.Content | ConvertFrom-Json
    throw "Token request failed: HTTP $($tokenResponse.StatusCode); $($details.error); $($details.error_description)"
}
$token = $tokenResponse.Content | ConvertFrom-Json
if (-not $token.access_token -or $token.token_type -ne 'Bearer') {
    throw 'The token endpoint did not return a Bearer access token.'
}
$headers = @{ Authorization = "Bearer $($token.access_token)"; Accept = 'application/json' }
$token = $null
$tokenResponse = $null

$baseUrl = 'https://graph.microsoft.com/beta/admin/windows/updates/catalog/entries'
$query = [ordered]@{
    '$top' = '12'
    '$filter' = "isof('microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry')"
    '$expand' = 'microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/productRevisions'
    '$orderby' = 'releaseDateTime desc'
}
$cases = @(
    @{ Name = '1. No query parameters'; Keys = @() }
    @{ Name = '2. top only'; Keys = @('$top') }
    @{ Name = '3. top + filter'; Keys = @('$top', '$filter') }
    @{ Name = '4. top + filter + expand'; Keys = @('$top', '$filter', '$expand') }
    @{ Name = '5. Full agent query'; Keys = @('$top', '$filter', '$expand', '$orderby') }
)
$failed = 0
try {
    foreach ($case in $cases) {
        $pairs = foreach ($key in $case.Keys) {
            '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString($query[$key])
        }
        $uri = $baseUrl
        if ($case.Keys.Count -gt 0) {
            $uri += '?' + ($pairs -join '&')
        }
        $requestId = [guid]::NewGuid().ToString()
        $headers['client-request-id'] = $requestId
        $headers['return-client-request-id'] = 'true'
        Write-Output "`n$($case.Name)"
        Write-Output "GET $uri"
        $response = Invoke-WebRequest -Uri $uri -Headers $headers `
            -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 60
        Write-Output "HTTP $($response.StatusCode); client-request-id: $requestId"
        Write-Output "request-id: $($response.Headers['request-id'] -join ','); date: $($response.Headers['Date'] -join ',')"
        if ($response.StatusCode -eq 200) {
            $data = $response.Content | ConvertFrom-Json
            if (-not ($data.PSObject.Properties.Name -contains 'value')) {
                throw 'Graph returned HTTP 200 without a catalog value collection.'
            }
            Write-Output "Entries: $(@($data.value).Count); nextLink present: $([bool]$data.'@odata.nextLink')"
        }
        else {
            $failed++
            $contentType = $response.Headers['Content-Type'] -join ','
            if ($contentType -match 'application/json') {
                $details = $response.Content | ConvertFrom-Json
                Write-Output "error.code: $($details.error.code)"
                Write-Output "error.message: $($details.error.message)"
            }
            else {
                Write-Output "Non-JSON error response; Content-Type: $contentType"
            }
            if ($response.StatusCode -ne 400) {
                throw "Stopped after HTTP $($response.StatusCode). Inspect the error above before retrying."
            }
        }
    }
}
finally {
    $headers.Clear()
}

if ($failed -gt 0) {
    throw "$failed Graph requests failed. Share the case names, statuses, error codes/messages and request IDs above, not credentials."
}
Write-Output "`nAll five direct Graph requests succeeded. Compare Security Copilot's actual inputs and loaded OpenAPI with case 5."
