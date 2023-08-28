# Create Folder Object List
$BigList = New-Object System.Collections.ArrayList

# Get Directory List From start location - Level 0
$CFolders = Get-ChildItem 'D:\'

foreach ($citem in $CFolders) {

	# echo $citem.FullName
	
	try {
		if (($citem.FullName -match "D:\\Windows")){
			#echo "Folder skipped"
		}
		else
		{
			# Get Level 1 Subfolders
			if ( $citem -is [io.directoryinfo] ) {
				$C1Folders = Get-ChildItem $citem.FullName -ErrorAction SilentlyContinue
				$C1Folders | Foreach-Object -process {
					$fname = $_.fullname
					$len = 0
					# 
					Get-ChildItem -recurse $_.FullName -ErrorAction SilentlyContinue | % { $len = $len + $_.length }
					$folder = New-Object System.Object
					$folder | Add-Member -MemberType NoteProperty -Name "FolderName" -Value  ('"' + $fname + '"')
					$folder | Add-Member -MemberType NoteProperty -Name "Size" -Value $len
					$BigList.add($folder) | Out-Null
				}
			}
			
		}
	}
	catch {
		# Just skip current folder
	}
}

# Store the first 10 bigger folders in dedicated list object
$TopList = $BigList | Sort-Object -Property Size -Descending | Select-Object -First 10
echo $TopList
