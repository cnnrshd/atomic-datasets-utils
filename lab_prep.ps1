# Script I use for prepping a lab machine
# Disables Defender, excludes AtomicRedTeam directory
# Installs:
# - Atomic-RedTeam (and Invoke-AtomicRedTeam)
# - Chocolatey
#   - Python 3.10
#   - Sysinternals
#   - VSCode
# - Export-WinEvents from Security-Datasets
# - My two Sysmon Configs
# Sets auditpol for everything to max
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -ExclusionPath C:\AtomicRedTeam\*
# Grab Atomic-RedTeam, install to C:\AtomicRedTeam
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -force
# install chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# install tools
choco install sysinternals vscode python310 -y
# set a file type association between xml and code
# will still need to check the "Keep using Code" box, but this gets it to show up
cmd.exe /c ftype xmlfile="C:\Program Files\Microsoft VS Code\Code.exe" %1
# Get the log collection script from Security-Datasets
New-Item C:\Scripts\Export-WinEvents -ItemType Directory -Force
IWR "https://raw.githubusercontent.com/OTRF/Security-Datasets/master/scripts/data-collectors/Export-WinEvents.ps1" -UseBasicParsing -OutFile C:\Scripts\Export-WinEvents\Export-WinEvents.psm1
# Grab two Sysmon configs - a high exclusion one and a research one
New-Item C:\Configs -ItemType Directory
IWR "https://gist.githubusercontent.com/cnnrshd/b07cf1e7894e381b820fba29bc6362f6/raw/be50009c398c87d2977a50b4bcbcc414bcc877b8/sysmon_research.xml" -UseBasicParsing -OutFile C:\Configs\research_config.xml
IWR "https://raw.githubusercontent.com/cnnrshd/sysmon-modular/master/config_lists/default_list/default_list_config.xml" -UseBasicParsing -OutFile C:\Configs\standard_config.xml
# Set auditpol to get all possible events
auditpol /set /category:*
