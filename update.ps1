Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-PSRepository PSGallery -InstallationPolicy Trusted

$Output = "$($PSScriptRoot)\output"
Remove-Item $Output -Recurse -Force -ErrorAction SilentlyContinue

$M = Import-Module MsrcSecurityUpdates -RequiredVersion 1.9.6 -PassThru -ErrorAction SilentlyContinue
if (-not $M) {
    Install-Module MsrcSecurityUpdates -RequiredVersion 1.9.6 -Force -Scope CurrentUser
}

# Load function
function Format-XML ([xml]$xml, $indent=2)
{
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}

# Create the cvfr doc xml
Get-CVRFID |
Where-Object { $_ -match "^$((Get-Date).ToString('yyyy-MMM',[System.Globalization.CultureInfo]'en-US'))"}|
ForEach-Object {
 $cvrfID = $_
 $cvrfDocument = Get-MsrcCvrfDocument -ID $_
 $cvrfDocumentXML = Get-MsrcCvrfDocument -ID $_ -asXML

 Format-XML -xml $cvrfDocumentXML -indent 2 |
 Out-File -FilePath (Join-Path -Path $Output -ChildPath "cvrfDocument-$($cvrfID).xml") -Encoding utf8

 $cvrfDocument | Get-MsrcVulnerabilityReportHtml |
 Out-File -FilePath (Join-Path -Path $Output -ChildPath "Bulletin-$($cvrfID).html") -Encoding utf8
}

# Get the Number of the cvrf doc revision pulled from API
$OnlineVer = $cvrfDocumentXML.cvrfdoc.DocumentTracking.RevisionHistory.Revision.Number

if (-not(Test-Path -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))" -PathType Container)) {
 mkdir "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document"
 mkdir "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\html-bulletin"
}

if (Test-Path -Path "$($PSScriptRoot)\2023\xml-cvrf-document\cvrfDocument-$($cvrfID).xml" -PathType Leaf) {
 $RepoVer = ([xml](Get-Content -Path "$($PSScriptRoot)\2023\xml-cvrf-document\cvrfDocument-$($cvrfID).xml")).cvrfdoc.DocumentTracking.RevisionHistory.Revision.Number
}

if ($RepoVer) {
    if ($OnlineVer -gt $RepoVer) {
        'Update required, online version: {0}, repo version: {1}' -f $OnlineVer,$RepoVer
    } else {
        'No update required, online version: {0}, repo version: {1}' -f $OnlineVer,$RepoVer
    }
} else {
 'Need to add {0} version {1}' -f $cvrfID,$OnlineVer
}