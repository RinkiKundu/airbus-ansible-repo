@ECHO OFF
Title %0
rem ...............................................
rem Template 2020-09-28
rem CMDLogFile with FullTimestamp
rem
rem  Parameters for PowerShell script
rem -XMLFile "%XMLFile%"
rem -LogFile "%CMDLogFile%"
rem -StartTranscript 
rem -MasterLogFile "%CMDMasterLogFile%"
rem -FullCmdFileName %FullCmdFileName%
rem ...............................................

rem Current folder
SET CurrDir=%~dp0

rem CMD file name without extension
SET CMDName=%~n0

rem full cmd file name
SET FullCmdFileName=%~f0

rem ~~~ Select LogCategory ~~~ 
SET LogCategory=MyWM
rem SET LogCategory=Scripts
rem SET LogCategory=SOFTS
rem ~~~~~~~~~~~~~~~~~~~~~~~~~~~ 

rem ~~~ Select CMDMasterLogFileName ~~~~~~~~~~~~~~~
SET CMDMasterLogFileName=MyWM.log
rem SET CMDMasterLogFileName=AutomatedInstallation.log
rem ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SET CMDMasterLogDir=%SystemDrive%\~LOGS\%LogCategory%
SET CMDMasterLogFile=%CMDMasterLogDir%\%CMDMasterLogFileName%
rem
SET CMDLogDir=%CMDMasterLogDir%\%CMDName%
rem --- New FullTimestamp ---
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
rem set "datestamp=%YYYY%%MM%%DD%" & set "timestamp=%HH%%Min%%Sec%"
set "FullTimestamp=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

rem --- SET CMDLogFile ---
SET CMDLogFile=%CMDLogDir%\%CMDName%_%FullTimestamp%.log

rem -- Select PS exe file --
SET PSEXE=Powershell.exe
rem SET PSEXE=%CurrDir%PS_6.2.3\pwsh.exe

SET PSFileName=%CMDName%.ps1
rem SET PSFileName=Main.ps1
SET PSFile=%CurrDir%%PSFileName%

SET XMLFile=%CurrDir%%CMDName%.xml
SET WaitSec=5

rem ================================================================
rem Create "%CMDMasterLogDir%" if not exist.
rem ================================================================
IF NOT EXIST "%CMDMasterLogDir%" MKDIR "%CMDMasterLogDir%"

rem =======================================================================
rem First write to "%CMDMasterLogFile%" (file will be created if not exist)
rem =======================================================================
Call :sEchoAndWriteMasterLog ------ Start %CMDName% ------
Call :sEchoAndWriteMasterLog Started: '%FullCmdFileName%'

rem ================================================================
rem Create "%CMDLogDir%" if no exist. Delete "%CMDLogFile%" if exist
rem ================================================================
IF NOT EXIST "%CMDLogDir%" MKDIR "%CMDLogDir%"
IF EXIST "%CMDLogFile%" del /F "%CMDLogFile%"

rem =============================================================
rem Check if "%PSFile%" exist.
rem =============================================================
Call :sEchoAndWrite Check if "%PSFile%" file exist...
IF NOT EXIST "%PSFile%" (
	SET ExitCode=19998
	SET FileNotExist=%PSFile%
	goto FileNotExist
)
Call :sEchoAndWrite File "%PSFile%" exist...

rem =============================================================
rem Check if "%XMLFile%" exist.
rem =============================================================
Call :sEchoAndWrite Check if "%XMLFile%" file exist...
IF NOT EXIST "%XMLFile%" (
	SET ExitCode=19998
	SET FileNotExist=%XMLFile%
	goto FileNotExist
)
Call :sEchoAndWrite File "%XMLFile%" exist...

rem =============================================================
rem Check if current user has local administrator rights
rem =============================================================
Call :sEchoAndWrite current cmd user - %username%@%COMPUTERNAME%

fltmc >nul 2>&1 && (
   Call :sEchoAndWrite user has local administrator rights - OK
) || (
   SET ExitCode=19999
   goto NotAdmin
)

Call :sEchoAndWrite : Start PowerShell script ...
Color 1F

rem ============= Call PowerShell ================================================================================================================================================================
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%PSFile%" -XMLFile "%XMLFile%" -LogFile "%CMDLogFile%" -StartTranscript -MasterLogFile "%CMDMasterLogFile%" -FullCmdFileName %FullCmdFileName%
rem ============ Return to CMD ===================================================================================================================================================================
SET ExitCode=%errorlevel%

if "%ExitCode%"=="0" goto PowerShellNoErrors
rem if "%ExitCode%"=="3010" goto E3010
if "%ExitCode%"=="20666" goto E20666
if "%ExitCode%"=="20777" goto E20777
goto AllOtherExitCodes
rem goto AllPowerShellErrors

:PowerShellNoErrors
Call :sEchoAndWrite PowerShell execution - OK! PowerShell ExitCode = %ExitCode%.
Color 2F
goto ExitCMD

rem ======== Errors ===========
rem -------- CMD Errors. Color CF -------
:FileNotExist
Color CF
Call :sEchoAndWrite CMD Error! File "%FileNotExist%" not found! Exit %ExitCode%.
goto ExitCMD

:NotAdmin
Color CF
Call :sEchoAndWrite CMD Error! %username%@%USERDNSDOMAIN% MUST be ADMINISTRATOR! Exit %ExitCode%.
goto ExitCMD

rem :E3010 - installation OK. Reboot needed.
:E3010
Call :sEchoAndWrite PowerShell execution - OK! PowerShell ExitCode = %ExitCode%. Installation - OK. Reboot needed. Set ExitCode = 0.
Set ExitCode=0
Color 2F
goto ExitCMD

rem :E20666 --- Unknown PowerShell error. Color 4F --------
:E20666
Color 4F
Call :sEchoAndWrite Unknown PowerShell error! Check PowerShell transcript file. Exit %ExitCode%.
goto ExitCMD

rem :E20777 - Reboot code returned.
:E20777
Call :sEchoAndWrite PowerShell execution - OK! PowerShell ExitCode = %ExitCode%. Installation - OK. Reboot needed. Set ExitCode = 0.
Set ExitCode=0
Color 2F
shutdown /r /t 15
goto ExitCMD

rem ----- CMD & PowerShell errors. Color 6F --------
:AllOtherExitCodes
if %ExitCode% LSS 20000 (
	Color 60
	Call :sEchoAndWrite CMD script ended with '%ExitCode%' exit code.
) else (
	Color 6F
	Call :sEchoAndWrite PowerShell script is intentionally ended with '%ExitCode%' exit code. Check '%CMDLogFile%' log file.	
)
goto ExitCMD

rem ======== EXIT ==========
:ExitCMD
Call :sEchoAndWriteMasterLog %CMDName% Ended with ExitCode=[%ExitCode%]
Call :sEchoAndWriteMasterLog Find more logs in %CMDLogDir%
Call :sEchoAndWriteMasterLog ----------- End %CMDName% --------------------------

Call :sEchoAndWrite : CMD ended with ExitCode=[%ExitCode%]
Call :sEchoAndWrite ------------ CMD END -------------- 
echo Wait %WaitSec% sec... Then exit.
PING 127.0.0.1 -n %WaitSec% >NUL 2>&1 || PING ::1 -n %WaitSec% >NUL 2>&1
rem echo PAUSE && EXIT
rem PAUSE && EXIT
exit %ExitCode%

rem ======== Functions ===========
:sEchoAndWrite
echo %*
echo [%date% %time:~0,-3%] : %* >> "%CMDLogFile%"
GOTO :eof

:sEchoAndWriteMasterLog
echo %*
echo [%date% %time:~0,-3%] : %* >> "%CMDMasterLogFile%"
GOTO :eof
