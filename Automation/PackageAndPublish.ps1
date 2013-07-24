Set-ExecutionPolicy Unrestricted -Force
import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

$key =  "[INSERT YOUR AMAZON AWS KEY]"
$keySecret = "[INSER YOUR AMAZON AWS SECRET]"

# S3 Bucket name where the file will be stored
$S3BucketName = "[INSERT YOUR S3 BUCKET NAME]"	

# S3 Bucket folder name within your S3 bucket where the package will reside.
$S3FolderName = "packages"

# The name of the package filename we'll be uploading
$S3PackageName = "websitedeployment"

# Amazon region that your S3 Bucket and your EC2 instances will reside.
$AmazonRegion = [Amazon.RegionEndpoint]::USEast1

#########################################################################################
cls
$path = split-path -parent $MyInvocation.MyCommand.Definition
$parentPath = split-path -Parent $path
Set-Location $path

function Add-Zip
{
    param([string]$zipfilename)
    if(-not (test-path($zipfilename)))
    {
        set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $zipfilename).IsReadOnly = $false  
    }
    $shellApplication = new-object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfilename)
    foreach($file in $input) 
    { 
        $zipPackage.CopyHere($file.FullName)
        while($zipPackage.Items().Item($file.Name) -Eq $null)
        {
        	start-sleep -seconds 1
        	write-host "." -nonewline
        }        
    }
	write-host ""
}
###############################################
# PACKAGE DEPLOYMENT FILES
###############################################
New-Item -ItemType directory -Path $parentPath\DeployTemp -Force
Move-Item $parentPath\Deployment* ..\DeployTemp\

# zip, zip file (and anything else needed).
$packageFullPath = "$parentPath\DeployTemp\${S3PackageName}.zip"
If (Test-Path $packageFullPath){
    Remove-Item $packageFullPath -Force
}

echo "Creating deployment package at $packageFullPath"
dir $parentPath\DeployTemp\*.* -Recurse | Add-Zip $packageFullPath
Remove-Item $parentPath\DeployTemp\Deployment* -Force

###############################################
# UPLOAD DEPLOYMENT PACKAGE TO S3
###############################################

function Hash-MD5 ($file) {
    $cryMD5 = [System.Security.Cryptography.MD5]::Create()
    $fStream = New-Object System.IO.StreamReader ($file)
    $bytHash = $cryMD5.ComputeHash($fStream.BaseStream)
    $fStream.Close()
    return [Convert]::ToBase64String($bytHash)
}

$S3FilePath = "${S3FolderName}/$S3PackageName"
$S3ClientConfig = new-object Amazon.S3.AmazonS3Config
$S3ClientConfig.RegionEndpoint = $AmazonRegion

$AmazonS3 = [Amazon.AWSClientFactory]::CreateAmazonS3Client($key, $keySecret, $S3ClientConfig)
$S3PutRequest = New-Object Amazon.S3.Model.PutObjectRequest 
$S3PutRequest.BucketName = $S3BucketName

$S3FilePathSuffix = "${S3FilePath}-latest.zip".ToLower()
$S3PutRequest.Key = $S3FilePathSuffix
$S3PutRequest.FilePath = $packageFullPath
$strMD5 = Hash-MD5($packageFullPath)
$S3PutRequest.MD5Digest = $strMD5
echo "Uploading package $S3FilePathSuffix to S3..."
$S3Response = $AmazonS3.PutObject($S3PutRequest)

$dateString = Get-Date -format "yyyyMMddmmss"
$S3FilePathSuffix = "${S3FilePath}-${dateString}.zip".ToLower()
echo "Uploading package $S3FilePathSuffix to S3..."
$S3PutRequest = New-Object Amazon.S3.Model.PutObjectRequest 
$S3PutRequest.BucketName = $S3BucketName
$S3PutRequest.Key = $S3FilePathSuffix
$S3PutRequest.FilePath = $packageFullPath
$strMD5 = Hash-MD5($packageFullPath)
$S3PutRequest.MD5Digest = $strMD5
$S3Response = $AmazonS3.PutObject($S3PutRequest)

#If upload fails it will throw an exception and $S3Response will be $null
if($S3Response -eq $null){
    Write-Error "ERROR: Amazon S3 put request failed. Script halted."
    exit 1
}