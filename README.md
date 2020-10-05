# Posh-FGT-LE

This script updates a Fortigate Admin & SSLVPN Certificate with LetsEncrypt.

## How To Use:

### First Time Setup

First things first, you NEED to have a PAAccount setup before running this script. This script was only designed to handle renewals, not the entire process. To learn more, please see the documentation at [Posh-ACME](https://github.com/rmbolger/Posh-ACME). An example to setup an account:

```powershell
New-PACertificate -Domain fg.example.com,fgt.example.com,vpn.example.com -AcceptTOS -Contact me@example.com -DnsPlugin Cloudflare -PluginArgs @{CFAuthEmail="me@example.com";CFAuthKey='xxx'}

# After the above completes, run the following
$Fortigate = "<ip or hostname of fgt>"
$Credential = Get-Credential
$MainDomain = 'fg.example.com'

# the '-UseExisting' flag is useful when the certifcate is not yet expired
./Update-FortigateLECert.ps1 -Fortigate $Fortigate -Credential $Credential -MainDomain $MainDomain -UseExisting
```

Otherwise, to normally run it:

```powershell
./Update-FortigateLECert.ps1 -Fortigate $Fortigate -Credential $Credential -MainDomain $MainDomain
```

### Force Renewals

You can force a renewal with the '-ForceRenew' switch:

```powershell
./Update-FortigateLECert.ps1 -Fortigate $Fortigate -Credential $Credential -MainDomain $MainDomain -ForceRenew
```

# TODO: Clean up script

This script still needs to be cleaned up, but it works for my needs at home. A co-worker was curious how I was updating my Lets Encrypt certs on my Fortigate, so I sanitized it a bit and threw it up GitHub.
