REM to log output to a file use PowerShell.exe >log.txt  etc etc
PowerShell.exe -ExecutionPolicy Bypass -File "Build-Configuration.ps1" "D:\Dev\git\Transformer\website" "D:\Dev\git\Transformer\build\output" environments.txt files.txt 
