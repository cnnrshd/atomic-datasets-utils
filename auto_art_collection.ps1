param(
    [Parameter()]
    [string]
    $TestRoot = "Z:\ArtTests",

    [Parameter()]
    [int]
    $StartTest = 0,

    [Parameter()]
    [int]
    $EndTest = 2000,

    [Parameter()]
    [string]
    $DefaultConfig = "C:\Configs\standard_config.xml",

    [Parameter()]
    [string]
    $ResearchConfig = "C:\Configs\research_config.xml"
)

import-module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
import-module "C:\Scripts\Export-WinEvents\Export-WinEvents.psm1"

$TestDirectory = "$($TestRoot)\Tests"
$Date = Get-Date -Format "yyyy_MM_dd"

$Channels = @('Security', 'Microsoft-Windows-Sysmon/Operational')

if (!(Test-Path $TestDirectory)) {
    New-Item $TestDirectory -ItemType Directory -Force
}

$techniques = Get-ChildItem C:\AtomicRedTeam\atomics\* -Recurse -Include T*.yaml | Get-AtomicTechnique

# Set the research config
Sysmon64.exe -c $ResearchConfig | ForEach-Object{ "$_" }

$TotalTestCount = 0

foreach ($technique in $techniques) {
    $Count = 1
    if ($TotalTestCount -gt $EndTest) {
      break
    }
    foreach ($atomic in $technique.atomic_tests) {
        if ($atomic.supported_platforms.contains("windows") -and ($atomic.executor -ne "manual")) {
            $TotalTestCount += 1
            if ($TotalTestCount -lt $StartTest) {
              continue
            } elseif ($TotalTestCount -gt $EndTest ) {
              break
            }
            
            $TechniqueID = ($technique.attack_technique -join ',')
            
            $TestStatus = "Failed"
            $CheckResponse = "NA"
            $Failure = "NA"
            $TestResponse = "NA"
            
            $TestFolder = "$TestDirectory\$TechniqueID\$Count"
            if (!(Test-Path $TestFolder)) {
                New-Item -Path $TestFolder -Force -ItemType Directory
            }
            # Get Prereqs for test
            Invoke-AtomicTest $technique.attack_technique -TestGuids $atomic.auto_generated_guid -GetPrereqs -InformationVariable PrereqResponse
            if ($PrereqResponse | Select-String -Quiet "Failed to meet prereq") {
                $Failure = "Failed to meet Prereq"
            } elseif ($PrereqResponse | Select-String -Quiet "Elevation required but not provided") {
                $Failure = "Possible Elevation Error"
            } else {
                Invoke-AtomicTest $technique.attack_technique -TestGuids $atomic.auto_generated_guid -CheckPrereqs -InformationVariable CheckResponse
                # TODO: check that prereq was successfully acquired
                if ($CheckResponse | Select-String -Quiet "Prerequisites not met") {
                    $Failure = "Error - Failed CheckPrereq after Successful GetPrereq"
                } else {
                    # I tried using -StartDate and -EndDate but it didn't work
                    $Channels | Clear-WinEvents
                    # Invoke
                    Invoke-AtomicTest $technique.attack_technique -TestGuids $atomic.auto_generated_guid -InformationVariable TestResponse
                    # Sleep 1 second & export
                    Start-Sleep 1
                    $Channels | Export-WinEvents -OutputFolder $TestFolder
                    # Clean
                    Invoke-AtomicTest  $technique.attack_technique -TestGuids $atomic.auto_generated_guid -Cleanup
                    # Dump test data to files
                    $TestStatus = "Successful"
                }
            }
            $StatusObj = [PSCustomObject]@{
                Status = $TestStatus
                Technique = $TechniqueID
                TestNumber = $Count
                PrereqResponse = $PrereqResponse.MessageData.Message | Out-String
                CheckResponse = $CheckResponse.MessageData.Message | Out-String
                TestResponse = $TestResponse.MessageData.Message | Out-String
                Date = $Date
                Time = Get-Date -Format "HH_mm_ss"
                GUID = $atomic.auto_generated_guid
                Failure = $Failure
            }
            $StatusObj | ConvertTo-Json | Out-File "$($TestFolder)\status.json"
        }
        $Count += 1
    }
}

Sysmon64.exe -c $DefaultConfig | ForEach-Object{ "$_" }
