#Powershell
## Get today's date for the new directory #>
$varDate = get-date -format "yyyy-MM-dd-HH-mm"
##Precheck Migration W2K12 to W2K16
ipconfig /all > D:\Temp\Migration\Pre-Migration_ipconfig_$varDate.txt
net localgroup administrators > D:\Temp\Migration\Pre-Migration_local_administrators_$varDate.txt



#Get-Service | Where-Object {$_.Starttype -eq "Auto" -and $_.Status -eq "Running"} | select-Object -property servicename, displayname, status, startType | Export-Csv -path "D:\Temp\Migration\Pre-GetServiceRunning.csv"

#Get-Service | Where-Object {$_.Starttype -eq "Auto" -and $_.Status -eq "Running"} | select-Object -property servicename, displayname, status, startType | Export-Csv -path "D:\Temp\Migration\Pre-GetServiceRunning_$varDate.csv"

#-----------------------------------------------------------------
