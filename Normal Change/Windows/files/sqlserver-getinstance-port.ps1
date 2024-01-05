Param (
	[String] $SERVERNAME,
	[String] $SQLINSTANCEARG
)

#
if (-Not $SERVERNAME) {
	write-host "ARGUMENT ERROR - Requested SERVERNAME is empty."
	[Environment]::Exit(1)
}

# Remove dns suffix
$ShortName = $SERVERNAME
$Suffix = ''
try {
	if ($SERVERNAME -match '^(?<shortname>[\w-]+)\.(?<suffix>[\w-\.]+)$') {
		$ShortName = $Matches.shortname
		$Suffix = $Matches.suffix
	}
}
catch {}

#
$InstanceFilter = ''
if ($SQLINSTANCEARG) {
	if ($SQLINSTANCEARG.ToLower() -ne 'all'){
		$InstanceFilter = $SQLINSTANCEARG
	}
}


$SQLINSTANCE = 'DEFAULT'
$SQLPORT = 10004
$SQLDBNAME = 'AUTOMATION'
try {
	$strSQL = "SELECT DISTINCT  name , port FROM SQLDBCON WHERE LOWER(name) LIKE LOWER('$ShortName%')"
	if ($InstanceFilter){
		if ($InstanceFilter -eq 'DEFAULT'){
			# 20200930
			$strSQL = "SELECT DISTINCT  name , port FROM SQLDBCON WHERE (LOWER(name) LIKE LOWER('%$ShortName%')) AND ( LOWER(name) LIKE LOWER('%$InstanceFilter%') )"
		}
		else {
			$strSQL = "SELECT DISTINCT  name , port FROM SQLDBCON WHERE (LOWER(name) LIKE LOWER('$ShortName%')) AND ( LOWER(name) LIKE LOWER('%$InstanceFilter%') )"
		}
	}
	$Rows = Invoke-Sqlcmd -ServerInstance "localhost\$SQLINSTANCE,$SQLPORT" -Database $SQLDBNAME -Query "$strSQL"
}
catch {
	write-host "EXCEPTION Unable to get SQL Server Instance for $SERVERNAME."
	[Environment]::Exit(2)
}

if (-Not $Rows){
	$str = [String]::Format("{0}#EMPTY#EMPTY", $SERVERNAME)
	Write-Host $str
	[Environment]::Exit(0)
}

$ExitCode = 0
try {
   
	# Send to output all found instances
	$str = ""
	$strPrev = ""
	$strCurr = ""
    foreach( $r in $Rows ){
		# 20200930 - Case of entry format from sqldbcon is reversed : DEFAULT_FR0-VSIAAS-288
		if ($r.name -match '^DEFAULT[_\\\.,/][\w\.-]+$'){
			$strCurr = [String]::Format("{0}#DEFAULT#{1}", $SERVERNAME, $r.port)
		}
		else {
			$tname = $r.name.Replace('_','#').Replace('\','#') -split ","
			$strCurr = [String]::Format("{0}#{1}", $tname[0],$r.port)
		}
		
		if ($strPrev.ToLower() -ne $strCurr.ToLower()){
			if ($str){
				$str = $str + ";" + $strCurr
			}
			else {
				$str = $strCurr
			}
			$strPrev = $strCurr
		}		
    }
	Write-Host $str
}
catch {
	write-host "EXCEPTION - Unable to recover SQL Server Instance for $SERVERNAME."
	$ExitCode = 3
}

[Environment]::Exit($ExitCode)
