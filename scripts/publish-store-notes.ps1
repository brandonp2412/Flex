param(
    [Parameter(Mandatory=$true)][string]$ProductId,
    [Parameter(Mandatory=$true)][string]$NotesFile,
    [string]$PlayVersionCode
)
$ErrorActionPreference = 'Stop'
$notes = (Get-Content -LiteralPath $NotesFile -Raw -Encoding UTF8).Trim()
if (-not $notes -or $notes.Length -gt 500) { throw 'Missing or oversized release notes' }
$token = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$env:NOTES_TENANT_ID/oauth2/token" -ContentType 'application/x-www-form-urlencoded' -Body @{
    grant_type = 'client_credentials'
    client_id = $env:NOTES_CLIENT_ID
    client_secret = $env:NOTES_CLIENT_SECRET
    resource = 'https://manage.devcenter.microsoft.com'
}
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$appUrl = "https://manage.devcenter.microsoft.com/v1.0/my/applications/$ProductId"
$app = Invoke-RestMethod -Headers $headers -Uri $appUrl
$id = $app.pendingApplicationSubmission.id
if (-not $id) { throw 'No pending Store submission' }
$url = "$appUrl/submissions/$id"
$submission = Invoke-RestMethod -Headers $headers -Uri $url
if ($submission.status -ne 'PendingCommit') { throw "Expected a draft submission, got $($submission.status)" }
$updated = 0
foreach ($listing in $submission.listings.PSObject.Properties) {
    $text = $null
    if ($listing.Name -match '^en(?:-|$)') { $text = $notes }
    elseif ($PlayVersionCode) {
        $locale = $listing.Name.ToLowerInvariant()
        $playLocales = @{
            'ar-sa'='ar'; 'de-de'='de-DE'; 'es-es'='es-ES'; 'fa-ir'='fa'; 'fr-fr'='fr-FR'
            'id-id'='id'; 'ja-jp'='ja-JP'; 'ko-kr'='ko-KR'; 'pl-pl'='pl-PL'
            'pt-pt'='pt-PT'; 'pt-br'='pt-BR'; 'ru-ru'='ru-RU'; 'th-th'='th'; 'ur-pk'='ur'
            'zh-cn'='zh-CN'; 'zh-tw'='zh-TW'
        }
        if ($playLocales.ContainsKey($locale)) {
            $file = "fastlane/metadata/android/$($playLocales[$locale])/changelogs/$PlayVersionCode.txt"
            $text = (Get-Content -LiteralPath $file -Raw -Encoding UTF8).Trim()
        }
    }
    if ($null -ne $text) {
        if (-not $text -or $text.Length -gt 500 -or $null -eq $listing.Value.baseListing) { throw "Invalid notes or listing: $($listing.Name)" }
        $listing.Value.baseListing | Add-Member -NotePropertyName releaseNotes -NotePropertyValue $text -Force
        $updated++
    }
}
if (-not $updated) { throw 'No supported Store listing found' }
$payload = $submission | ConvertTo-Json -Depth 100 -Compress
$result = Invoke-RestMethod -Method Put -Uri $url -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
if ($result.id -ne $id -or $result.status -ne 'PendingCommit') { throw 'Store did not retain the intended pending submission' }
& msstore submission publish $ProductId
if ($LASTEXITCODE -ne 0) { throw 'Microsoft Store submission publish failed' }
