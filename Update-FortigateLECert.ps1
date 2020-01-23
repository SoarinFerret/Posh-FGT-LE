<#
.SYNOPSIS
This is a simple Powershell Core script to update Fortigate SSL certificate with a LetsEncrypt cert

.DESCRIPTION
This script uses the Posh-Acme module to RENEW a LetsEncrypt certificate, and then adds it to a Fortigate over SSH. This is designed to be ran consistently, and will not update the cert if Posh-Acme hasn't been setup previously.

.EXAMPLE
./Update-FortigateLECert.ps1 -Fortigate 10.0.0.1 -Credential (new-credential admin admin) -MainDomain fg.example.com

.NOTES
This requires Posh-Acme to be preconfigured. The easiest way to do so is with the following command:
    New-PACertificate -Domain fg.example.com,fgt.example.com,vpn.example.com -AcceptTOS -Contact me@example.com -DnsPlugin Cloudflare -PluginArgs @{CFAuthEmail="me@example.com";CFAuthKey='xxx'}

This can only be ran on a Windows host until Posh-SSH becomes cross-platform. Look at the below link for more details:
    https://github.com/darkoperator/Posh-SSH/issues/130

.LINK
https://github.com/SoarinFerret/Posh-FGT-LE

#>

Param(
    [string]$Fortigate,
    [Parameter(ParameterSetName = "SecureCreds")]
    [pscredential]$Credential,
    [Parameter(ParameterSetName = "PlainTextPassword")]
    [string]$Username,
    [Parameter(ParameterSetName = "PlainTextPassword")]
    [String]$Password,
    [String]$MainDomain
)


Import-WinModule Posh-SSH
Import-Module Posh-Acme

Write-Output "Starting Certificate Renewal"
$cert = Submit-Renewal -MainDomain $MainDomain
if($cert){
    Write-Output "...Renewal Complete!"

    if($PSCmdlet.ParameterSetName -eq "PlainTextPassword"){
        Write-Warning "You shouldn't use plaintext passwords on the commandline"
        $Credential = New-Credential -Username $env:FGT_USER -Password $env:FGT_PASS
    }
    $session = New-SSHSession -ComputerName $Fortigate -Credential $Credential -AcceptKey

    if($session.Connected){
        Write-Output "Updating the CA on the FGT"
        $out = Invoke-SSHCommand -SessionId $session.sessionid -Command "config vpn certificate ca
        edit `"LetsEncryptCA`"
        set ca `"$(gc $cert.ChainFile -Raw)`"
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating CA failed: $($out.Error)"
        }

        # This gets ran twice - why you ask? No idea. Makes cert blank if only ran once ¯\_(ツ)_/¯
        Write-Output "Updating the LetsEncrypt Certificate on the FGT"
        $out = Invoke-SSHCommand -SessionId $session.sessionid "config vpn certificate local
        edit `"LetsEncrypt`"
        set certificate `"$(gc $cert.CertFile -Raw)`"
        set private-key `"$(gc $cert.KeyFile -Raw)`"
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating LE certificate failed: $($out.Error)"
        }
        Write-Output "Updating the LetsEncrypt Certificate on the FGT"
        $out = Invoke-SSHCommand -SessionId $session.sessionid "config vpn certificate local
        edit `"LetsEncrypt`"
        set certificate `"$(gc $cert.CertFile -Raw)`"
        set private-key `"$(gc $cert.KeyFile -Raw)`"
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating LE certificate failed: $($out.Error)"
        }
        
        Write-Output "Updating the Admin certificate on the FGT"
        $out = Invoke-SSHCommand -SessionId $session.sessionid -Command "config system global
        unset admin-server-cert
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating the admin certificate failed: $($out.Error)"
        }
        $out = Invoke-SSHCommand -SessionId $session.sessionid -Command "config system global
        set admin-server-cert `"LetsEncrypt`"
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating the admin certificate failed: $($out.Error)"
        }

        Write-Output "Updating the SSLVPN certificate on the FGT"
        $out = Invoke-SSHCommand -SessionId $session.sessionid -Command "config vpn ssl settings
        unset servercert
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating the SSLVPN certificate failed: $($out.Error)"
        }
        $out = Invoke-SSHCommand -SessionId $session.sessionid "config vpn ssl settings
        set servercert `"LetsEncrypt`"
        end
        "
        if($out.ExitStatus -ne 0){
            Write-Error "Updating the SSLVPN certificate failed: $($out.Error)"
        }

        # Disconnect Session
        if(Remove-SSHSession -SessionId $session.sessionid){
            Write-Output "Finished!"
        }
    }
}else{
    Write-Output "No need to update certificate!"
}
