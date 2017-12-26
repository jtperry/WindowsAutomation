# WindowsAutomation

My collection of tools to automate Windows.

##FireBoxstarter.ps1
This is a script cobbled together of others to install BoxStarter from an elevated window and install based on my personal GIST.  You can update the $gist variable to run for yourself.  Purpose is to configure a Windows 10 box for your liking.

Irony here.  I didn't want to have to count on "install some script and fire" so I reviewed scripts and built my own via copy/paste.  This way **I** could count on what was there.  This creates the irony of someone else needing to download and run my script.  But this is for me not you.  :-)

To run:
iwr -useb https://raw.githubusercontent.com/jtperry/WindowsAutomation/master/FireBoxstarter.ps1 -OutFile ./FireBoxstarter.ps1
./FireBoxstarter.ps1
