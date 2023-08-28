# Compress Trigger Size threshold
$SzCompressThreshold = 1MB

# Get Directory List From start location - Level 0
$CFolders = Get-ChildItem 'D:\'

foreach ($citem in $CFolders) {
	
	try {
		# echo $citem.FullName
		
		if (($citem.FullName -match "C:\\Windows")){
			echo "C:\\Windows Folder skipped"
		}
		else {
		
			$C1Folders = Get-ChildItem -Path $citem.FullName -recurse -Force -ErrorAction SilentlyContinue
			foreach ($c1 in $C1Folders) {
			
				try {		
					# echo "$c1"
					if ( $c1 -is [io.FileInfo] ) {
						if ( ($c1.extension -eq ".log") -or ($c1.extension -eq ".txt") ) {
							if ( ($c1.length -gt $SzCompressThreshold) -and ($c1.Attributes -notlike "*Compressed*") ){
								compact /C $c1.FullName | Out-Null
								echo $c1.FullName $c1.Length
							}
						}
					}
				}
				catch {
					# Just skip current item
				}
			}
		}
	}
	catch {
		# Just skip current folder
	}
	
}
