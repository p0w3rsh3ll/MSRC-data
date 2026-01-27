[CmdletBinding()]
Param()
Begin {
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
}
Process {}
End {
    if ($PSVersionTable.PSEdition -eq 'Desktop') { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force }
    Set-PSRepository PSGallery -InstallationPolicy Trusted

    $Output = Join-Path -Path "$($PSScriptRoot)" -ChildPath 'output'
    Remove-Item $Output -Recurse -Force -ErrorAction SilentlyContinue

    if ($PSVersionTable.Platform -eq 'Unix') {
     $null = Import-Module (Join-Path -Path "$($PSScriptRoot)" -ChildPath 'MsrcSecurityUpdates\1.9.8\MsrcSecurityUpdates.psd1') -Force
    } else {
     $M = Import-Module MsrcSecurityUpdates -RequiredVersion 1.9.6 -PassThru -ErrorAction SilentlyContinue
     if (-not $M) {
         $null = Install-Module MsrcSecurityUpdates -RequiredVersion 1.9.6 -Force -Scope CurrentUser
         $null = Import-Module MsrcSecurityUpdates -RequiredVersion 1.9.6 -PassThru -ErrorAction SilentlyContinue
     }
    }

    # dot source private function
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
    . (Join-Path (Split-Path (Get-Module -Name MsrcSecurityUpdates -ListAvailable).Path) -ChildPath 'Private\Get-CVRFID.ps1')
    } else {
     $global:msrcApiUrl     = 'https://api.msrc.microsoft.com/cvrf/v3.0'
     $global:msrcApiVersion = 'api-version=2023-11-01'
     . (Join-Path -Path "$($PSScriptRoot)" -ChildPath 'MsrcSecurityUpdates/1.9.8/Private/Get-CVRFID.ps1')
    }

    if (-not(Test-Path -Path $Output -PathType Container)) {
     $null = mkdir $Output
    }

    $cvrfID = Get-CVRFID |
    Where-Object { $_ -match "^$((Get-Date).ToString('yyyy-MMM',[System.Globalization.CultureInfo]'en-US'))"} |
    Select-Object -Unique

    if ($cvrfID) {
        # Create the cvfr doc xml
        $cvrfID |
        ForEach-Object {
         $cvrfDocument = Get-MsrcCvrfDocument -ID $_ -WarningAction SilentlyContinue
         $cvrfDocumentXML = Get-MsrcCvrfDocument -ID $_ -asXML -WarningAction SilentlyContinue

         Format-XML -xml $cvrfDocumentXML -indent 2 |
         Out-File -FilePath (Join-Path -Path $Output -ChildPath "cvrfDocument-$($cvrfID).xml") -Encoding utf8

         $cvrfDocument | Get-MsrcVulnerabilityReportHtml -ExcludeMarinerTag -WarningAction SilentlyContinue |
         Out-File -FilePath (Join-Path -Path $Output -ChildPath "Bulletin-$($cvrfID).html") -Encoding utf8
        }

        # Get the Number of the cvrf doc revision pulled from API
        $OnlineVer = [int]($cvrfDocumentXML.cvrfdoc.DocumentTracking.RevisionHistory.Revision.Number)
        $OnlineReleaseDate = [datetime]($cvrfDocumentXML.cvrfdoc.DocumentTracking.CurrentReleaseDate)

        # Display content
        $content = ($cvrfDocument).Vulnerability | Where-Object { ($_.Notes | Where-Object type -eq '7').Value -ne 'Mariner' }|
        Foreach-Object {
         $v = $_
         [PSCustomObject]@{
          CVEID = $v.CVE
          Title = $v.Title.Value
          Date = $($v.RevisionHistory | Select-Object -First 1 -ExpandProperty Date)
          Revision = $($v.RevisionHistory | Select-Object -First 1 -ExpandProperty Number)
         }
        } | Sort-Object -Property Date

        if (-not(Test-Path -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))" -PathType Container)) {
         mkdir "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document"
         mkdir "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\html-bulletin"
        }

        if (Test-Path -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml" -PathType Leaf) {
         $RepoVer = [int](([xml](Get-Content -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml")).cvrfdoc.DocumentTracking.RevisionHistory.Revision.Number)
         $RepoReleaseDate = ([datetime](([xml](Get-Content -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml")).cvrfdoc.DocumentTracking.CurrentReleaseDate)) #.ToString('s')
        }
    } else {
        'Nothing online'
        Remove-Item $Output -Recurse -Force -ErrorAction SilentlyContinue
        exit 0
    }

    if ($content) {
     # Testing the count of vulnerability
     if (Test-Path -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml" -PathType Leaf) {
         $RepoCVECount = (([xml](Get-Content -Path "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml")).cvrfdoc.Vulnerability.CVE).Count
         if ($RepoCVECount -lt ($cvrfDocumentXML.cvrfdoc.Vulnerability.CVE).Count) {
                 'Update required, online CVE count: {0}, repo count: {1}' -f "$(($cvrfDocumentXML.cvrfdoc.Vulnerability.CVE).Count)",$RepoCVECount
         } else {
                 'No update required, CVE count: {0}, repo count: {1}' -f  "$(($cvrfDocumentXML.cvrfdoc.Vulnerability.CVE).Count)",$RepoCVECount
         }
     }

     if ($RepoVer) {
         if ($OnlineVer -gt $RepoVer) {
             'Update required, online version: {0}, repo version: {1}' -f $OnlineVer,$RepoVer
             'Update required, online release date: {0}, repo release date: {1}' -f $OnlineReleaseDate,$RepoReleaseDate
             Copy-Item -Path (Join-Path -Path $Output -ChildPath "cvrfDocument-$($cvrfID).xml") -Destination "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($cvrfID).xml"
             Copy-Item -Path (Join-Path -Path $Output -ChildPath "Bulletin-$($cvrfID).html") -Destination "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\html-bulletin\Bulletin-$($cvrfID).html"
         } else {
             'No update required, online version: {0}, repo version: {1}' -f $OnlineVer,$RepoVer
             'No update required, online release date: {0}, repo release date: {1}' -f $OnlineReleaseDate,$RepoReleaseDate
         }
     } else {
      $cvrfID | Foreach-Object {
       'Need to add {0} version {1}, released {2}' -f $_,$OnlineVer,$OnlineReleaseDate
        Copy-Item -Path (Join-Path -Path $Output -ChildPath "cvrfDocument-$($_).xml") -Destination "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\xml-cvrf-document\cvrfDocument-$($_).xml"
        Copy-Item -Path (Join-Path -Path $Output -ChildPath "Bulletin-$($_).html") -Destination "$($PSScriptRoot)\$((Get-Date).Tostring('yyyy'))\html-bulletin\Bulletin-$($_).html"
      }
     }

     if ($content | Where-Object { [datetime]($_.Date) -ge (Get-Date).AddDays(-2)}) {
      $content | Where-Object { [datetime]($_.Date) -ge (Get-Date).AddDays(-2)}
     }
    }
    Remove-Item $Output -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}
