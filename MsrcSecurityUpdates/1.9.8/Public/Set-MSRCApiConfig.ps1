Function Set-MSRCApiConfig {
[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter()]
    [System.Uri]$Proxy,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $ProxyCredential = [System.Management.Automation.PSCredential]::Empty

)
Begin {}
Process {
    if ($PSCmdlet.ShouldProcess('Set config for MSRC API')) {
        # We set required shared variables
        $global:msrcApiUrl     = 'https://api.msrc.microsoft.com/cvrf/v2.0'
        Write-Verbose -Message "Successfully defined a msrcApiUrl global variable that points to $($global:msrcApiUrl)"

        $global:msrcApiVersion = 'api-version=2016-08-01'
        Write-Verbose -Message "Successfully defined a msrcApiVersion global variable that points to $($global:msrcApiVersion)"

        if ($ProxyCredential -ne [System.Management.Automation.PSCredential]::Empty) {
            $global:msrcProxyCredential = $ProxyCredential
            Write-Verbose -Message 'Successfully defined a msrcProxyCredential global variable'
        }

        if ($Proxy) {
            $global:msrcProxy = $Proxy
            Write-Verbose -Message "Successfully defined a msrcProxyCredential global variable that points to $($global:msrcProxy)"
        }
    }
}
End {}
}