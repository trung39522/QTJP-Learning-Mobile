param(
    [switch]$IndexOnly,
    [switch]$CheckIdentity
)

$ErrorActionPreference = 'Stop'
# Heuristic guard for this public repository; findings show locations, not values.
$repositoryRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { exit 1 }
Push-Location -LiteralPath $repositoryRoot
try {
    $paths = @(git -c core.quotepath=false ls-files)
    $findings = [System.Collections.Generic.List[string]]::new()
    $privatePath = '(?i)(^|/)(\.env($|\.(?!example$))|local\.properties$|key\.properties$|google-services\.json$|GoogleService-Info\.plist$|client_secret[^/]*\.json$|credentials[^/]*\.json$|service[-_]account[^/]*\.json$)|(^|/)config/(?![^/]+\.example\.json$)|\.(?:local\.(?:json|ya?ml|md|xcconfig)|jks|keystore|p12|pfx|pem|mobileprovision|db|sqlite3?|har|hprof|dump|apk|aab|ipa)$|^(?:build|\.dart_tool|\.vscode)/'
    $rules = [ordered]@{
        'Private key' = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
        'Credential token' = '(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9_-]{32,})'
        'Local Google client identifier' = '[0-9]{8,}-[a-z0-9]+\.apps\.googleusercontent\.com'
        'Personal certificate fingerprint' = '(?:[A-F0-9]{2}:){19,}[A-F0-9]{2}'
        'Personal email address' = '[A-Z0-9._%+-]+@(?:gmail|yahoo|outlook|hotmail|icloud)\.com\b'
        'Machine-specific path' = '[A-Z]:[\\/](?:Users|Development|Do_An)[\\/]'
        'Possible device serial' = '\b(?=[A-Z0-9]{14,20}\b)(?=[A-Z0-9]*[0-9])(?=[A-Z0-9]*[G-Z])[A-Z0-9]+\b'
    }
    foreach ($path in $paths) {
        if ($path -match $privatePath) {
            $findings.Add("${path}: private/local file must not be tracked")
        }
    }
    foreach ($rule in $rules.GetEnumerator()) {
        # Read tracked text directly through Git; never print matching content.
        $pattern = if ($rule.Key -eq 'Possible device serial') { $rule.Value } else { '(?i)' + $rule.Value }
        if ($IndexOnly) {
            $hits = @(git grep --cached -I -n --no-color -P -e $pattern -- .)
        } else {
            $hits = @(git grep -I -n --no-color -P -e $pattern -- .)
        }
        if ($LASTEXITCODE -gt 1) { throw 'Git could not scan tracked text.' }
        foreach ($hit in $hits) {
            if ($hit -match '^(.+?):(\d+):') {
                $findings.Add("$($Matches[1]):$($Matches[2]): $($rule.Key)")
            }
        }
    }
    if ($CheckIdentity) {
        foreach ($identityKind in @('GIT_AUTHOR_IDENT', 'GIT_COMMITTER_IDENT')) {
            $identity = git var $identityKind
            if ($LASTEXITCODE -ne 0) { throw 'Configure a public Git identity before committing.' }
            if ($identity -match '<([^>]+)>' -and $Matches[1] -notmatch '@users\.noreply\.github\.com$|^noreply@') {
                $findings.Add("${identityKind}: use a GitHub no-reply address for public commits")
            }
        }
    }
    if ($findings.Count -gt 0) {
        Write-Output 'Public repository check blocked these locations (values hidden):'
        $findings | ForEach-Object { Write-Output " - $_" }
        exit 1
    }
    Write-Output "Public repository check passed for $($paths.Count) tracked files."
} finally {
    Pop-Location
}
