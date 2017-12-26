#
# This script is to get an elevated powershell instance and then run boxstarter based on GIST
# Code to grab elevated Powershell script is from Theod Thompson here :https://github.com/MicrosoftDocs/Virtualization-Documentation/blob/master/hyperv-tools/Nested/Enable-NestedVm.ps1
# Code to install BoxStarter is from here but didn't want to randomly download what could eventually be hijacked domain: http://boxstarter.org/bootstrapper.ps1
#

# Set the URL to the GIST to install
$gist = "https://gist.githubusercontent.com/jtperry/4b54e64c34e40767580340381a274cf6/raw/04c44465ef6b08a7f71ab2adf2da581d77edc68a/gistfile1.txt"



##################################
#BoxStarter Install Script Begin
##################################
function Get-Boxstarter {
    Param(
        [string] $Version = "2.10.3",
        [switch] $Force
    )
    if(!(Test-Admin)) {
        $bootstrapperFile = ${function:Get-Boxstarter}.File
        if($bootstrapperFile) {
            Write-Host "User is not running with administrative rights. Attempting to elevate..."
            $command = "-ExecutionPolicy bypass -noexit -command . '$bootstrapperFile';Get-Boxstarter $($args)"
            Start-Process powershell -verb runas -argumentlist $command
        }
        else {
            Write-Host "User is not running with administrative rights.`nPlease open a powershell console as administrator and try again."
        }
        return
    }

    $badPolicy = $false
    @("Restricted", "AllSigned") | ? { $_ -eq (Get-ExecutionPolicy).ToString() } | % {
        Write-Host "Your current Powershell Execution Policy is set to '$(Get-ExecutionPolicy)' and will prohibit boxstarter from operating propperly."
        Write-Host "Please use Set-ExecutionPolicy to change the policy to RemoteSigned or Unrestricted."
        $badPolicy = $true
    }
    if($badPolicy) { return }

    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Check-Chocolatey -Force:$Force){
        Write-Output "Chocolatey installed, Installing Boxstarter Modules."
        $chocoVersion  = "2.9.17"
        try {
            New-Object -TypeName Version -ArgumentList $chocoVersion.split('-')[0] | Out-Null
            $command = "cinst Boxstarter -y"
        }
        catch{
            # if there is no -v then its an older version with no -y
            $command = "cinst Boxstarter"
        }
        $command += " --version $version"
        Invoke-Expression $command
        Import-Module "$env:ProgramData\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1" -Force
        $Message = "Boxstarter Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of Boxstarter has been aborted."
    }
    if($Force) {
        Write-Host $Message
    }
    else {
        Read-Host $Message
    }
}

function Check-Chocolatey {
    Param(
        [switch] $Force
    )
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall\bin\choco.exe")){
        $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4 or greater, that will also be downloaded and installed."
        Write-Host $message
        if($Force -OR (Confirm-Install)){
            $exitCode = Enable-Net40
            if($exitCode -ne 0) {
                Write-Warning ".net install returned $exitCode. You likely need to reboot your computer before proceeding with the install."
                return $false
            }
            $env:ChocolateyInstall = "$env:programdata\chocolatey"
            New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
            $url="https://chocolatey.org/api/v2/package/chocolatey/"
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            iex ($wc.DownloadString("https://chocolatey.org/install.ps1"))
            $env:path="$env:path;$env:ChocolateyInstall\bin"
        }
        else{
            return $false
        }
    }
    return $true
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        Write-Host "Downloading .net 4.5..."
        Get-HttpToFile "http://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
        Write-Host "Installing .net 4.5..."
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "$env:temp\net45.exe"
        $pinfo.Verb="runas"
        $pinfo.Arguments = "/quiet /norestart /log $env:temp\net45.log"
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $p.WaitForExit()
        $e = $p.ExitCode
        if($e -ne 0){
            Write-Host "Installer exited with $e"
        }
        return $e
    }
    return 0
}

function Get-HttpToFile ($url, $file){
    Write-Verbose "Downloading $url to $file"
    if(Test-Path $file){Remove-Item $file -Force}
    $downloader=new-object net.webclient
    $wp=[system.net.WebProxy]::GetDefaultProxy()
    $wp.UseDefaultCredentials=$true
    $downloader.Proxy=$wp
    try {
        $downloader.DownloadFile($url, $file)
    }
    catch{
        if($VerbosePreference -eq "Continue"){
            Write-Error $($_.Exception | fl * -Force | Out-String)
        }
        throw $_
    }
}

function Confirm-Install {
    $caption = "Installing Chocolatey"
    $message = "Do you want to proceed?"
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
    }
}

function Test-Admin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

################################
#End BoxStarter install Code
################################


###############
#Begin run elevated Code
###############
# Need to run elevated.  Do that here.
#

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    # We are running as an administrator, so change the title and background colour to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";

    } else {
    # We are not running as an administrator, so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

    # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
    $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null;

    # Exit from the current, unelevated, process
    Exit;
    }

###############
#End run elevated Code
###############

# Now we have an elevated instance.  Let's make sure boxstarter installed
# First make sure RemoteSigned is enabled
Set-ExecutionPolicy RemoteSigned

#Fire off the BoxStarter install Code
get-boxstarter -Force

#Now install the GIST we have above
Install-BoxstarterPackage -PackageName $gist

