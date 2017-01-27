<# 
Get-VmHighCpuReady

This script identifies any VM that has CPU Ready metrics above a threshold within a set period. 
Single vm or all vms in a cluster can be checked


.Description
    Get vm's network info
	russ 05/01/2016
	
.Acknowledgments 
 The absolutely brilliant Jason Coleman - http://virtuallyjason.blogspot.com.es/
    
.Example
    ./Get-VmHighCpuReady
	./Get-VmHighCpuReady <vm> 
	
	ie for a single vm: GGet-VmHighCpuReady -VM <Virtual Machine Name> 
	-Days <# of days to attempt to read> 
	-Threshold <% as an integer above which to report>

Multiple outputs are generated if the vm passed the threshold value multiple times 
It reports when each VM experienced the load 


Set value for [Ready] Threshold (only values above this are collected) - set at 19.9%
Set value to 3 days -  this take into account vCenter stats roll up
	vCenter > administration > statistics Interval Duration 5 Minutes = 3 Days
	Statistics level = 3
#>


# Set variables
[CmdletBinding()]
param (
[alias("v")]
[string]$VM = " ",
[alias("d")]
[int]$Days = 3,
[alias("t")]
[int]$Threshold = 9.9,
[alias("m")]
[string]$metric = "cpu.ready.summation"
)

Write-host "this script identifies any VM that has CPU Ready metrics above a threshold"
Write-host "to run on single vm cancel and execute ./Get-VmHighCpuReady <vm>"

# Set file path, filename, date and time
# This is my standard path, you should adjust as needed
$filepath = "C:\vSpherePowerCLI\Output\"
$filename = "vmReady"
$initalTime = Get-Date
$date = Get-Date ($initalTime) -uformat %Y%m%d
$time = Get-Date ($initalTime) -uformat %H%M

Write-Host "---------------------------------------------------------" -ForegroundColor DarkYellow
Write-Host "Output will be saved to:"  			   		-ForegroundColor Yellow
Write-Host $filepath$filename-$date$time".csv"  			-ForegroundColor White
Write-Host "---------------------------------------------------------" -ForegroundColor DarkYellow

# Create empty results array to hold values
$resultsarray =@()


# Option to run script against a single vm or specific cluster
# Remove the Get Cluster section and replace with $vms = Get-VM to run on all vms in vcenter
if ($vm -eq " "){
    # Get Cluster info and populate $vms  
	$Cluster = Get-Cluster  
	$countCL = 0  
	Write-Output " "  
	Write-Output "Clusters: "  
	Write-Output " "  
		foreach($oC in $Cluster){  
        Write-Output "[$countCL] $oc"  
        $countCL = $countCL+1  
        }  
	$choice = Read-Host "Which Cluster do you want to review?"  
	Write-Output " "  
	Write-host "please wait for script to finish, it may take a while...." -ForegroundColor Yellow
	$cluster = get-cluster $cluster[$choice] 
	$vms = Get-cluster $cluster | Get-VM
	
	
}

else{
$vms = Get-VM -name $VM
}

# Set start time
$start = (Get-Date).AddDays(-$Days)


# Outer loop - iterates $vms
foreach ($vm in $vms)
		{   
		
		# Inner loop - collects stat values of $metric for each vm in Svms
		foreach ($Report in $(Get-Stat -Entity $vm -IntervalSecs 300 -Stat $metric -Start $start -Erroraction "silentlycontinue")){
                $ReadyPercentage = (($Report.Value/10)/$Report.IntervalSecs)
                if ($ReadyPercentage -gt $Threshold){
                    $PerReadable = "$ReadyPercentage".substring(0,4)
                    write-output "$($Report.Entity), $($Report.Timestamp), $PerReadable%"
					
					# Create an array object to hold results, and add data as attributes using the add-member commandlet
					$resultObject = new-object PSObject
					$resultObject | add-member -membertype NoteProperty -name "Entity" -Value $Report.Entity
					$resultObject | add-member -membertype NoteProperty -name "Timestamp" -Value $Report.Timestamp
					$resultObject | add-member -membertype NoteProperty -name "cpu.ready.summation" -Value $PerReadable%
	
					# Write array output to results 
					$resultsarray += $resultObject
					
                }
            }	
}


# output to gridview
$resultsarray | Out-GridView
 
# export to csv 
# $resultsarray| Export-csv C:\vSpherePowerCLI\Output\vmCpuPeak.csv -notypeinformation
$resultsarray | Export-Csv $filepath$filename"-"$cluster"-"$date$time".csv" -NoType
