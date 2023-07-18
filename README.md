# atomic-datasets-utils

Holds info and tools for automating Atomic-RedTeam test collection and processing.

The goal with this repo is to include all the tools or references to tools you'd need to replicate my data collection. I've run Atomic-RedTeam against several Windows 2019 servers with a [very broad Sysmon config](https://gist.githubusercontent.com/cnnrshd/b07cf1e7894e381b820fba29bc6362f6/raw/be50009c398c87d2977a50b4bcbcc414bcc877b8/sysmon_research.xml) so that I can run them against my [Sysmon toolset](https://github.com/cnnrshd/sysmon_utils) for determining *actual* coverage, not just *theoretical* coverage against different techniques.

## Workflow

1. Make a Windows VM (or several) to test against
2. [Update PowerShell to Version 7](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.3) or you're going to have a rough time with [UTF-8BOM or UTF-16LE later on](https://stackoverflow.com/a/34969243).
3. Run [lab_prep.ps1](./lab_prep.ps1) against each VM
4. Run [auto_art_collection.ps1](./auto_art_collection.ps1) against each VM - be sure to specify StartTest and EndTest if running on multiple systems
5. Merge all the results
    - I had each VM write to the same Test directory on an SMB share (Unraid cache SSD) so they were auto-meged, YMMV - in my testing it was about 3GB of logs
6. Move the data to a Linux or Mac to run the shell scripts (Or WSL). 
    - Optionally, convert the `sh` scripts to PowerShell - ForEach-Object should function similarly to `find -exec`
    - The data size should be ~70-90MB when compressed to a ZIP, default options, so it's easy to move.
7. Run [find_successful_tests.sh](./find_successful_tests.sh) to get a JSON list of all tests that return successful
8. Run [merge_log_files.sh](./merge_log_files.sh) to combine all log files for each test into their own json file - Each [auto_art_collection.ps1](./auto_art_collection.ps1) run will extract each logging Channel to a separate file, such as "Sysmon", "Security", etc. This merges all of those files into a single `.json` for each event.
10. Go to my [Sysmon toolset](https://github.com/cnnrshd/sysmon_utils) to test your data (May update this repo with a script to run those tests)
    - For testing, I will alternate between `sysmon_utils atomictests` and `sysmon_utils merge` - Run a test, look for missing detections, add them to Sysmon config, re-run.

### Issues

These tools allow for (mostly) unattended data collection. Below are some caveats.

- Some tests will [break data collection](https://github.com/cnnrshd/atomic-datasets-utils/issues/5). Right now I've tried to hard-code some techniques to avoid, but for some reason my Exclude on T1562 isn't working. If you use the -StartTest and -EndTest flags, T1562 is around 830-840, so you can run two iterations - one with -EndTest 830 and one with -StartTest 850.
- Some tests have [manual prerequisite installation steps](https://github.com/cnnrshd/atomic-datasets-utils/issues/2). This is an issue with the prereq installation a subset of Atomic-RedTeam tests.

## Utils

### [lab_prep.ps1](./lab_prep.ps1)

Script I use for prepping a lab machine. Disables Defender, excludes AtomicRedTeam directory from scanning (in case it turns back on - this doesn't help with tests that install to C:\Temp, but you won't need to redownload), sets auditpol to max, installs all prereqs for running [auto_art_collection.ps1](./auto_art_collection.ps1):
- Atomic-RedTeam (and Invoke-AtomicRedTeam)
- Chocolatey
  - Python 3.10
  - Sysinternals
  - VSCode
- Export-WinEvents from Security-Datasets
- My two Sysmon Configs
Sets auditpol for everything to max

### auto_art_collection.ps1

This script is used for running Atomic-RedTeam tests and collecting the resulting logs from the Security and Sysmon channels.

#### auto_art_collection.ps1 prereqs

Prerequsites for this script are pretty much covered by the [lab prep script](./lab_prep.ps1):

- Sysmon is installed
- Both used configs (research and standard) exist (Location can be changed with params, expected default is in `C:\Configs`
- Atomic-RedTeam is installed - this should also install PowerShell-Yaml
- PowerShell-Yaml is installed (Should be done by Atomic-RedTeam's install script)
- Invoke-AtomicRedTeam is installed - expected psd1 location is `C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1`
- Export-WinEvents from Security-Datasets is installed - expected location is `C:\Scripts\Export-WinEvents\Export-WinEvents.psm1`

### [find_successful_tests.sh](./find_successful_tests.sh)

Searches through the "status.json" files and extracts all successful tests to a new file, `successful_tests.json`, for use with [merge_log_files](#merge_log_files.sh)

#### find_successful_tests.sh prereqs

- jq

### [merge_log_files.sh](./merge_log_files.sh)

This tool will merge the Sysmon and Security (Or really any JSON file that matches the format) event logs into one JSONL file for easier testing.

#### merge_log_files.sh prereqs

- A file named `successful_tests.json` that contains `FilePath` - output of [find_successful_tests.sh](./find_successful_tests.sh)
- jq
