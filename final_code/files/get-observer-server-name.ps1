param ([string]$ORA_SID)
$name = sqlcmd -S "localhost\INWPDh2001,10004" -d AUTOMATION -E -Q "set nocount on ; select OBSERVER_SERVER_NAME from OBSERVER where DATABASE_NAME = '$ORA_SID'" -h -1
if ([string]::IsNullOrEmpty($name))
   {
      write-host "DATABASE_NAME_NOT_FOUND"
   }
else
   {
      $fqdn = sqlcmd -S "localhost\INWPDh2001,10004" -d AUTOMATION -E -Q "set nocount on ; select OBSERVER_SERVER_FQDN from OBSERVER where DATABASE_NAME = '$ORA_SID'" -h -1
      $name = $name -replace '\s',''
      $fqdn = $fqdn -replace '\s',''
      write-host "$name.$fqdn"
   }
