winget install azcopy -h


$fullPath = New-Item -Path $ENV:USERPROFILE -ItemType Directory -Name $Env:USERNAME



robocopy $ENV:USERPROFILE\desktop $fullPath\desktop /R:0 /W:0 /S /ZB /XJ /XO
robocopy $ENV:USERPROFILE\documents $fullPath\documents /R:0 /W:0 /S /ZB /XJ /XO
robocopy $ENV:USERPROFILE\downnloads $fullPath\downloads /R:0 /W:0 /S /ZB /XJ /XO
robocopy $ENV:USERPROFILE\pictures $fullPath\pictures /R:0 /W:0 /S /ZB /XJ /XO
robocopy $ENV:USERPROFILE\videos $fullPath\videos /R:0 /W:0 /S /ZB /XJ /XO
robocopy $ENV:USERPROFILE\favorites $fullPath\favorites /R:0 /W:0 /S /ZB /XJ /XO


 

 
#SAS Path
$saspath = "https://nwiazfs01.file.core.windows.net/profileupload/"
$saskey = "?sv=2022-11-02&ss=f&srt=c&sp=rwdlc&se=2024-01-02T02:08:11Z&st=2023-11-28T18:08:11Z&spr=https&sig=vahQq0aDEVxif8DhovAHgPSGvrYcMcOsAwj4vj2ByuM%3D"
$options = " --recursive"
 

$destPath = $saspath + $name + $saskey +$options
write-host $fullPath $destPath
azcopy copy  $fullPath $destpath