Set-ExecutionPolicy Unrestricted -Force
import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

$key =  "[INSERT YOUR AMAZON AWS KEY]"
$keySecret = "[INSER YOUR AMAZON AWS SECRET]"

$serverKey = "[INSERT THE NAME OF YOUR SERKEY KEYPAIR NAME WITHOU THE .PEM]"

$securityGroup = "[INSER YOUR SECURITY GROUP]"

$region = [Amazon.RegionEndpoint]::USEast1
$instanceSize="t1.micro"
$amiId = "ami-2bafd842"
$userDataFileName = ".\userData.ps1"

#########################################################
$path = split-path -parent $MyInvocation.MyCommand.Definition
$parentPath = split-path -Parent $path
Set-Location $path
cls

# get script to run on start up. Encode it with Base64
$userDataContent = Get-Content $userDataFileName -Raw
$bytes = [System.Text.Encoding]::Utf8.GetBytes($userDataContent)
$userDataContent = [Convert]::ToBase64String($bytes)

$ec2Config = new-object Amazon.EC2.AmazonEC2Config
$ec2Config.RegionEndpoint = $region
$client = [Amazon.AWSClientFactory]::CreateAmazonEC2Client($key,$keySecret,$ec2Config)
 
echo 'Launching Web Server' 
$runRequest = new-object Amazon.EC2.Model.RunInstancesRequest
$runRequest.ImageId = $amiId
$runRequest.KeyName = $serverKey
$runRequest.MaxCount = "1"
$runRequest.MinCount = "1"
$runRequest.InstanceType = $instanceSize
$runRequest.SecurityGroupId = $securityGroup 
$runRequest.UserData = $userDataContent

try{
    $runResp = $client.RunInstances($runRequest)
}
catch {
    echo $_.Exception.ToString()
    echo "Error occured while running instances. Exitting"
    Exit
}
Start-Sleep -s 1

$runResult = $runResp.RunInstancesResult.Reservation.RunningInstance[0].InstanceId 
$tmp = 1
$hostname = "" 

echo "Instance created: $runResult"
echo "Waiting for IP Address"
while ($tmp -eq 1)
{
	try
	{
		sleep(5)
		$ipReq = New-Object Amazon.EC2.Model.DescribeInstancesRequest
		$ipReq.InstanceId.Add($runResult)
		$ipResp = $client.DescribeInstances($ipReq)

		$hostname = $ipResp.DescribeInstancesResult.Reservation[0].RunningInstance[0].PublicDnsName
 
		if($hostname.Length -gt 0)
		{
			$tmp = 0
		}
	 }
	 catch{
		echo "Error occured: echo $_.Exception.ToString()"
		Exit
	 }
}
 
echo "New Amazon instance available at: http://$hostname"