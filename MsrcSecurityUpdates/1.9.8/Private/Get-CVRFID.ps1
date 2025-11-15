Function Get-CVRFID {
[CmdletBinding()]
[OutputType([System.String])]
Param(
    [Parameter()]
    [Alias('CVRFID')]
    [string]$ID
)
Begin {
}
Process {

    #region PlanA
    $RestMethod = @{
        uri = '{0}/Updates?{1}' -f $global:msrcApiUrl,$global:msrcApiVersion
        Headers = @{
            'Accept' = 'application/json'
        }
        ErrorAction = 'Stop'
    }
    if ($global:msrcProxy){

        $RestMethod.Add('Proxy' , $global:msrcProxy)
    }
    if ($global:msrcProxyCredential){

        $RestMethod.Add('ProxyCredential',$global:msrcProxyCredential)

    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = if ($ID) {
           (Invoke-RestMethod @RestMethod).Value |
            Where-Object { $_.ID -eq $ID } |
            Where-Object { $_ -ne '2017-May-B' }
        } else {
            ((Invoke-RestMethod @RestMethod).Value).ID |
            Where-Object { $_ -ne '2017-May-B' }
        }
        if ($ID) {
         Write-Verbose -Message "Testing ID: $($ID)"
         if ($ID -in $r.ID) {
          Write-Verbose -Message 'Finding cvrfId with plan A succeeded'
          $r.ID
         } else {
          Write-Verbose -Message 'Finding cvrfId with plan A did not failed but test plan B because current month is missing'
          $PlanB = $true
         }
        } else {
         Write-Verbose -Message "Testing with no ID"
         if ((Get-Date).ToString('yyyy-MMM',[CultureInfo]::InvariantCulture) -in @($r)) {
          Write-Verbose -Message 'Finding current month with plan A succeeded'
          $r
         } else {
          Write-Verbose -Message 'Finding current month with plan A did not failed but test plan B because current month is missing'
          $PlanB = $true
         }
        }

    } catch {
     Write-Verbose -Message "Failed to find cvrfId with plan A because $($_.Exception.Message)"
     $PlanB = $true
    }
    #endregion

    #region PlanB
    if ($PlanB) {
     # PlanB: test the full CVRFID Url
     if ($ID) {
      $RestMethod['uri']= 'https://api.msrc.microsoft.com/cvrf/v3.0/cvrf/{0}' -f $ID
     } else {
      $RestMethod['uri']= 'https://api.msrc.microsoft.com/cvrf/v3.0/cvrf/{0}' -f (Get-Date).ToString('yyyy-MMM',[CultureInfo]::InvariantCulture)
     }
     try {
      $isAvailable = (Invoke-RestMethod @RestMethod)
      Write-Verbose -Message 'Successfully executed planB to find cvrfID'
     } catch {
       # Throw $_
       Write-Warning -Message 'Failed to execute plan B to find cvrfID'
     }
     if ($isAvailable) {
      if ($ID) {
       return $ID
      } else {
       return $r+(Get-Date).ToString('yyyy-MMM',[CultureInfo]::InvariantCulture)
      }
     }
    }
    #endregion
}
End {}
}
