# script to install dotnet 48 framework
param(
    [switch]$restart
)

$url = "https://go.microsoft.com/fwlink/?linkid=2088631" 
$registryPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
$installedVersion = [version]((Get-ItemProperty -Path $registryPath -Name Version).Version)
$installedVersion

if($installedVersion -ge [version]("4.8")) {
    write-host "dotnet 4.8 already installed"
    return
}

$path = "$psscriptroot\ndp48-x86-x64-allos-enu.exe" 
$path    

"Downloading [$url]`nSaving at [$path]" 
(new-object System.Net.WebClient).DownloadFile($url, $path) 

$argumentList = "/q /log $psscriptroot\install.log"
if (!$restart) { $argumentList += " /norestart" }

Invoke-Command -ScriptBlock { Start-Process -FilePath $path -ArgumentList $argumentList -Wait -PassThru } 
Write-Host (Get-ItemProperty -Path $registryPath -Name Version).Version