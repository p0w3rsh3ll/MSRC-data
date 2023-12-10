Function Get-MSRCApiConfig {
[OutputType([System.Collections.Hashtable])]
[CmdletBinding()]
Param()
Begin {}
Process {
    $HT = @{}
    $HT.Add('msrcApiUrl',"$($global:msrcApiUrl)")
    $HT.Add('msrcApiVersion',"$($global:msrcApiVersion)")
    if ($global:msrcProxyCredential) {
        $HT.Add('msrcProxyCredential',$global:msrcProxyCredential)
    }
    if ($global:msrcProxy) {
        $HT.Add('msrcProxy',"$($global:msrcProxy)")
    }
    $HT
}
End {}
}