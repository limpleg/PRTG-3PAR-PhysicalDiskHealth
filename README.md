# PRTG-3PAR-PhysicalDiskHealth
Due to offical 3PAR Sensor don't monitor in my case the real disk health, here is a powershell script for just monitoring disk status

## 🧩 Prerequisites

- PRTG Probe system needs PowerShell and the plink.exe (from Putty) accessible in the EXEXML Path
- 3PAR user with permission to run showpd (read-only is fine)
- stored Hostkey on the Probe by connecting once with SSH to the 3PAR

## 🛠️ Installation
Copy the script to
C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\

## Create Sensor
- add an EXE/Script Advanced Sensor
- select PRTG-3PAR-PhysicalDiskHealth

and use following parameters:
-TargetHost YOURHOSTIP -User "3PARMONITORINGUSER" -Password "3PARMONITORINGPASSWORD" -HostKey "HOSTKEY"

<img width="1423" height="560" alt="image" src="https://github.com/user-attachments/assets/91b83699-cc10-42b3-a797-0ef72992d98f" />
