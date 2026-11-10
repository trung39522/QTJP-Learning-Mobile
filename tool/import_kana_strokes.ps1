# Rebuild the offline kana subset from the same upstream used by the website.
# Generated data is CC BY-SA 3.0; see assets/alphabet/KANJIVG_LICENSE.txt.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputDirectory = Join-Path $projectDirectory 'assets\alphabet'
$release = 'r20250816'
$upstream = "https://raw.githubusercontent.com/KanjiVG/kanjivg/$release"
$kanaSource = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $projectDirectory 'lib\screens\alphabet\models\kana.dart')
# Read only the declared hiragana data, then add corresponding katakana.
$codePoints = [System.Collections.Generic.SortedSet[int]]::new()
foreach ($match in [regex]::Matches($kanaSource, '[\u3041-\u3096]')) {
    $codePoint = [int][char]$match.Value
    [void]$codePoints.Add($codePoint)
    [void]$codePoints.Add($codePoint + 0x60)
}
if ($codePoints.Count -ne 148) {
    throw "Expected 148 unique kana glyphs; found $($codePoints.Count). Review the catalogue before importing."
}

Add-Type -AssemblyName System.Net.Http
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(30)
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$glyphs = [ordered]@{}
$copyrightNotices = [System.Collections.Generic.SortedSet[string]]::new()

try {
    # Small batches avoid a slow sequential download without flooding upstream.
    $points = @($codePoints)
    for ($offset = 0; $offset -lt $points.Count; $offset += 8) {
        $batch = @()
        foreach ($codePoint in $points[$offset..([Math]::Min($offset + 7, $points.Count - 1))]) {
            $hex = $codePoint.ToString('x5')
            $batch += @{ Point = $codePoint; Task = $client.GetStringAsync("$upstream/kanji/$hex.svg") }
        }
        foreach ($request in $batch) {
            $svg = $request.Task.GetAwaiter().GetResult()
            foreach ($notice in [regex]::Matches($svg, '(?m)^Copyright[^\r\n]+')) {
                [void]$copyrightNotices.Add($notice.Value)
            }
            $settings = [System.Xml.XmlReaderSettings]::new()
            # Internal namespace defaults are needed; external entities are disabled.
            $settings.DtdProcessing = [System.Xml.DtdProcessing]::Parse
            $settings.XmlResolver = $null
            $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($svg), $settings)
            $document = [System.Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            try { $document.Load($reader) } finally { $reader.Dispose() }
            $pathNodes = $document.SelectNodes("//*[local-name()='g' and starts-with(@id, 'kvg:StrokePaths_')]//*[local-name()='path']")
            if ($pathNodes.Count -eq 0) { throw "No stroke paths for $($request.Point)." }
            $paths = @()
            foreach ($path in $pathNodes) {
                if ($path.SelectNodes('ancestor-or-self::*[@transform]').Count -ne 0) {
                    throw 'Unexpected path transform; update importer rather than discarding it.'
                }
                $paths += $path.GetAttribute('d')
            }
            $numbers = @()
            foreach ($number in $document.SelectNodes("//*[local-name()='g' and starts-with(@id, 'kvg:StrokeNumbers_')]//*[local-name()='text']")) {
                $matrix = $number.GetAttribute('transform')
                $values = @([regex]::Matches($matrix, '-?\d+(?:\.\d+)?') | ForEach-Object {
                    [double]::Parse($_.Value, $invariant)
                })
                if ($values.Count -ne 6 -or $values[0] -ne 1 -or $values[1] -ne 0 -or $values[2] -ne 0 -or $values[3] -ne 1) {
                    throw "Unexpected stroke-number transform: $matrix"
                }
                $numbers += [ordered]@{ text = $number.InnerText; x = $values[4]; y = $values[5] }
            }
            $glyphs[[string][char]$request.Point] = [ordered]@{ paths = @($paths); numbers = @($numbers) }
        }
        Write-Output "Imported $($glyphs.Count)/$($points.Count) kana glyphs."
    }
    $license = $client.GetStringAsync("$upstream/COPYING").GetAwaiter().GetResult()
} finally { $client.Dispose() }

# Only write complete, validated imports. No website files are read or changed.
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$utf8 = [System.Text.UTF8Encoding]::new($false)
$data = [ordered]@{
    source = 'KanjiVG'
    version = $release
    sourceUrl = "https://github.com/KanjiVG/kanjivg/tree/$release"
    license = 'CC-BY-SA-3.0'
    licenseUrl = 'https://creativecommons.org/licenses/by-sa/3.0/'
    modifications = 'Kana subset; SVG paths and stroke-number positions converted to JSON. Paths are unchanged.'
    characters = $glyphs
}
[System.IO.File]::WriteAllText((Join-Path $outputDirectory 'kana_strokes.json'), ($data | ConvertTo-Json -Depth 10), $utf8)
$attribution = @(
    'KanjiVG - Kana stroke data',
    ($copyrightNotices -join "`n"),
    'Project: https://kanjivg.tagaini.net/',
    "Source: https://github.com/KanjiVG/kanjivg/tree/$release",
    'License: Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0)',
    'https://creativecommons.org/licenses/by-sa/3.0/',
    'QTJP changes: kana subset extracted; SVG paths and label coordinates converted to JSON; original paths unchanged.',
    'The adapted dataset is distributed under CC BY-SA 3.0.',
    '',
    $license
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $outputDirectory 'KANJIVG_LICENSE.txt'), $attribution, $utf8)
Write-Output 'Completed offline kana data and license import.'
