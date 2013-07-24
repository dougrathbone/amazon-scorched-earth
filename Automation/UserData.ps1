<powershell>
  Set-ExecutionPolicy Unrestricted -Force

  #############################################
  # Settings
  ############################################
  $urlForPackage = "http://[INSERT YOUR S3 BUCKET NAME].s3.amazonaws.com/packages/websitedeployment-latest.zip"
  $packageFileName = "DeploymentPackage"
  $iisWebsiteName = "mywebsite.com"

  ############################################
  $deployTempLocation = "c:\Data\DeployTemp"

  mkdir "c:\Data"
  mkdir $deployTempLocation

  #turn on logging to another file
  $ErrorActionPreference="SilentlyContinue"
  Stop-Transcript | out-null
  $ErrorActionPreference = "Continue"
  Start-Transcript -path C:\Data\AutomationLog.txt -append

  mkdir "c:\Data\Downloads"
  Set-Location "c:\Data\Downloads"

  $wc = New-Object System.Net.WebClient
  echo "downloading webdeploy"
  $webDeployInstallerUrl = "http://download.microsoft.com/download/1/B/3/1B3F8377-CFE1-4B40-8402-AE1FC6A0A8C3/WebDeploy_amd64_en-US.msi"
  $webDeployDownloadPath = "c:\Data\Downloads\webdeploy.msi"
  $wc.DownloadFile("$webDeployInstallerUrl",$webDeployDownloadPath)

  ############################
  # download deployment package from S3
  ############################
  Remove-Item "${deployTempLocation}\*" -Recurse -Force

  Set-Location $deployTempLocation
  $downloadFileName = "deploypackagetemp.zip"
  $packageDownloadFilePath = "$deployTempLocation\$downloadFileName"

  echo "downloading iis webdeploy package"
  $wc = New-Object System.Net.WebClient
  $wc.Headers.Add("user-agent", "diaryofaninjadeploy-4d8ae3a6-6efc-40dc-9a7c-bb55284b10cc");
  $wc.DownloadFile($urlForPackage,$packageDownloadFilePath)

  echo "unzipping iis webdeploy package"
  Set-Location $deployTempLocation
  $shell_app=new-object -com shell.application
  $zip_file = $shell_app.namespace($packageDownloadFilePath);
  $destination = $shell_app.namespace((Get-Location).Path)
  $destination.Copyhere($zip_file.items(),0x14)

  ############################
  # Install/setup IIS
  ############################

  Import-Module ServerManager
  echo "installing windows features"
  Add-WindowsFeature -Name Application-Server,Web-Common-Http,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Request-Monitor,Web-Basic-Auth,Web-Windows-Auth,Web-Filtering,Web-Performance,Web-Mgmt-Console,Web-Mgmt-Compat,WAS -IncludeAllSubFeature

  Import-Module WebAdministration
  # --------------------------------------------------------------------
  # Setting directory access
  # --------------------------------------------------------------------
  $InetPubWWWRoot = "C:\inetpub\wwwroot\"
  echo "setting security permissions on iis folders"
  $Command = "icacls $InetPubWWWRoot /grant BUILTIN\IIS_IUSRS:(OI)(CI)(RX) BUILTIN\Users:(OI)(CI)(RX)"
  cmd.exe /c $Command
  $Command = "icacls $InetPubWWWRoot /grant `"IIS AppPool\DefaultAppPool`":(OI)(CI)(M)"
  cmd.exe /c $Command

  echo "renaming default website"
  Rename-Item 'IIS:\Sites\Default Web Site' $iisWebsiteName

  echo "running iis reset"
  $Command = "IISRESET"
  Invoke-Expression -Command $Command

  echo "installing web deploy"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $webDeployDownloadPath /passive /log C:\Data\WebDeployInstallLog.txt" -Wait -Passthru

  echo "starting web deploy"
  net start msdepsvc

  Set-Location ${deployTempLocation}
  echo "Adding WebDeploy snapin"
  Add-PSSnapin WDeploySnapin3.0

  echo "invoking the webdeploy package (installing to iis)"
  Restore-WDPackage "${packageFileName}.zip"

  Stop-Transcript
</powershell>