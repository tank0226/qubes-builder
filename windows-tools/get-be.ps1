# Qubes builder - preparing Windows build environment
# Bootstrap: downloads 7zip, msys, then fetches qubes-builder off the repository and starts msys shell.

Function PathToUnix($path)
{
    # converts windows path to msys/mingw path
    $path = $path.Replace('\', '/')
    $path = $path -replace '^([a-zA-Z]):', '/$1'
    return $path
}

Function DownloadFile($url, $fileName)
{
    $uri = [System.Uri] $url
    if ($fileName -eq $null)  { $fileName = $uri.Segments[$uri.Segments.Count-1] } # get file name from URL 
    $fullPath = "$tmpDir\$fileName"
    Write-Host "[*] Downloading $pkgName from $url..."
    
    try
    {
	    $client = New-Object System.Net.WebClient
	    $client.DownloadFile($url, $fullPath)
    }
    catch [Exception]
    {
        Write-Host "[!] Failed to download ${url}:" $_.Exception.Message
        Exit 1
    }
    
    Write-Host "[=] Downloaded: $fullPath"
    return $fullPath
}

Function UnpackZip($filePath, $destination)
{
    Write-Host "[*] Unpacking $filePath..."
    $shell = New-Object -com Shell.Application
    $zip = $shell.Namespace($filePath)
    foreach($item in $zip.Items())
    {
        $shell.Namespace($destination).CopyHere($item)
    }
}

Function Unpack7z($filePath, $destination)
{
    Write-Host "[*] Unpacking $filePath..."
    $arg = "x", "-y", "-o$destination", $filePath
    & $7zip $arg | Out-Null
}

### start

$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
Set-Location $scriptPath

# log everything from this script
$Host.UI.RawUI.BufferSize.Width = 500
Start-Transcript -Path win-bootstrap.log

$tmpDir = "$scriptPath\tmp"
Remove-Item -Recurse -Force $tmpDir -ErrorAction Ignore | Out-Null
New-Item $tmpDir -ItemType Directory | Out-Null
Write-Host "[*] Tmp dir: $tmpDir"

# download tools
$pkgName = "7zip"
$url = "http://downloads.sourceforge.net/sevenzip/7za920.zip"
$file = DownloadFile $url
UnpackZip $file $tmpDir
$7zip = "$tmpDir\7za.exe"

$pkgName = "msys"
$url = "http://downloads.sourceforge.net/project/mingwbuilds/external-binary-packages/msys%2B7za%2Bwget%2Bsvn%2Bgit%2Bmercurial%2Bcvs-rev13.7z"
$file = DownloadFile $url
Unpack7z $file $tmpDir

# fetch qubes-builder off the repo
$repo = "git://git.qubes-os.org/marmarek/qubes-builder.git"
$builderPath = "$scriptPath\qubes-builder"
Write-Host "[*] Cloning qubes-builder to $builderPath"
& "$tmpDir\msys\bin\git.exe" "clone", "$repo", "$builderPath" | Out-Host

# move msys to qubes-builder
$prereqsDir = "$builderPath\windows-prereqs"
if (-not (Test-Path $prereqsDir)) { New-Item $prereqsDir -ItemType Directory | Out-Null }

Move-Item $tmpDir\msys $prereqsDir -Force

# cleanup
Write-Host "[*] Cleanup"
Remove-Item $tmpDir -Recurse -Force | Out-Null

Write-Host "[=] Done"
# set msys to start in qubes-builder directory
$builderUnix = PathToUnix $builderPath
$cmd = "cd $builderUnix"
Add-Content "$builderPath\windows-prereqs\msys\etc\profile" "`n$cmd"
# start msys shell as administrator
Start-Process -FilePath "$builderPath\windows-prereqs\msys\msys.bat" -Verb runAs