# A collection of functions used in the GUI scripts

# Checks if the required python libraries are installed
# We have to use python to convert lua to json, so we need to check if python is installed and has the required libraries (no lua support in PowerShell sadly)
function Test-PythonReq {
    $pythonCmd = (Get-Command python -ErrorAction SilentlyContinue)
    $requiredLibs = @("base64", "slpp", "json") 
    $missingLibs = @()
    
    if (-not $pythonCmd) {
        return $null
    }

    $ErrorActionPreference = 'SilentlyContinue'
    foreach ($lib in $requiredLibs) {
        python -c "import $lib" 2>&1 # test if the library is installed

        if ($LASTEXITCODE -ne 0) { $missingLibs += $lib }
    }
    $ErrorActionPreference = 'Continue'

    if ($missingLibs) {
        return $missingLibs
    } else {
        return $true
    }
}

# File prompt function for selecting files
function Select-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "All files (*.*)|*.*",
        
        [Parameter(Mandatory = $false)]
        [string]$Type = "OpenFileDialog"
    )

    Add-Type -AssemblyName System.Windows.Forms
    $FileDialog = $null
    try {
        if ($Type -eq "SaveFileDialog") {
            # Save File
            $FileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $FileDialog.Filter = $Filter
            $FileDialog.FilterIndex = 1
            $FileDialog.FileName = $FileName
        } elseif($Type -eq "OpenFileDialog") {
            # Open File
            $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $FileDialog.Filter = $Filter
            $FileDialog.Title = "Select $($FileName) file"
        } elseif($Type -eq "FolderBrowserDialog") {
            # Folder Browser
            $FileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $FileDialog.Description = "Select $($FileName) folder"
        }

        # Use the main window's handle so the popup is on top
        $dialogResult = $FileDialog.ShowDialog([System.Windows.Interop.WindowInteropHelper]::Handle)
        
        # Handle user result
        if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
            $resultPath = $null
            if ($Type -eq "FolderBrowserDialog") {
                $resultPath = $FileDialog.SelectedPath
            } else {
                $resultPath = $FileDialog.FileName
            }

            return $resultPath -replace "\\", "/"
        } else {
            return $null
        }
    } catch {
        Write-Warning "An error occurred while selecting the file: $_"
        return $null
    }
}

# Creates new window from XAML file
function New-XamlWindow {
    param (
        [string]$XamlPath
    )

    $XamlContent = [System.IO.File]::ReadAllText($XamlPath)
    $StringReader = New-Object System.IO.StringReader($XamlContent)
    $XmlReader = [System.Xml.XmlReader]::Create($StringReader)

    return [Windows.Markup.XamlReader]::Load($XmlReader)
}