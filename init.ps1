# Configuration (config.xaml) - Handles configuration of the session (including the inventory.data file, profile.data file, and ProfileImages folder), then passes it along to the other pages.

Add-Type -AssemblyName PresentationCore, PresentationFramework
$Window = $null
$Config = @{}
. "./assets/gui_func.ps1"

# ---- Initialize the Configuration Page ---- #
$Window = New-XamlWindow -XamlPath "./assets/pages/config.xaml"

# Check if all fields are filled
function Test-Config {
    if($Window.FindName("InventoryTextBox").Text -ne "" -and $Window.FindName("ProfileTextBox").Text -ne "" -and $Window.FindName("ImagesTextBox").Text -ne "") {
        $Window.FindName("StartButton").IsEnabled = $true
    } else {
        $Window.FindName("StartButton").IsEnabled = $false
    }
}

# Inventory Browse Button
$Window.FindName("BrowseInventoryButton").Add_Click({
    $result = Select-File -FileName "inventory.data" -Filter "Data files (*.data)|*.data"

    if ($result) {
        $Window.FindName("InventoryTextBox").Text = $result
    }
})

# Profile Browse Button
$Window.FindName("BrowseProfileButton").Add_Click({
    $result = Select-File -FileName "profile.data" -Filter "Data files (*.data)|*.data"

    if ($result) {
        $Window.FindName("ProfileTextBox").Text = $result
    }
})

# Images Browse Button
$Window.FindName("BrowseImagesButton").Add_Click({
    $result = Select-File -FileName "ProfileImages" -Type "FolderBrowserDialog"

    if ($result) {
        $Window.FindName("ImagesTextBox").Text = $result
    }
})

# Load Config Button
$Window.FindName("LoadConfigButton").Add_Click({
    $result = Select-File -FileName "config.json" -Filter "JSON files (*.json)|*.json"

    if ($result) {
        try {
            $config = Get-Content -Path $result | ConvertFrom-Json
            if($config.Inventory -and $config.Profile -and $config.Images) {
                $Window.FindName("InventoryTextBox").Text = $config.Inventory
                $Window.FindName("ProfileTextBox").Text = $config.Profile
                $Window.FindName("ImagesTextBox").Text = $config.Images
            } else {
                [System.Windows.MessageBox]::Show("The configuration file is missing required fields. Please check the file format and try again.", "Invalid Configuration", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        } catch {
            [System.Windows.MessageBox]::Show("An error occurred while loading the configuration file. Please check the file format and try again.", "Invalid Configuration", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

# Save Config Button
$Window.FindName("SaveConfigButton").Add_Click({
    $result = Select-File -FileName "config.json" -Filter "JSON files (*.json)|*.json" -Type "SaveFileDialog"

    if ($result) {
        $saveConfig = @{
            Inventory = $Window.FindName("InventoryTextBox").Text
            Profile = $Window.FindName("ProfileTextBox").Text
            Images = $Window.FindName("ImagesTextBox").Text
        }

        ($saveConfig | ConvertTo-Json -Depth 3) | Out-File -FilePath $result -Encoding UTF8
        [System.Windows.MessageBox]::Show("Your configuration has been successfully saved in the specified location.", "Configuration Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Start Button
$Window.FindName("StartButton").Add_Click({
    $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to continue? Before you proceed, please ensure that you have a backup of your data.", "Backup Warning", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
    
    if ($result -eq [System.Windows.MessageBoxResult]::OK) {
        if ((Test-Path $Window.FindName("InventoryTextBox").Text) -and 
        (Test-Path $Window.FindName("ProfileTextBox").Text) -and 
        (Test-Path $Window.FindName("ImagesTextBox").Text)) {
            $Config = @{
                Inventory = $Window.FindName("InventoryTextBox").Text
                Profile = $Window.FindName("ProfileTextBox").Text
                Images = $Window.FindName("ImagesTextBox").Text
            }

            $Window.Close() # Close the configuration window
            .\title.ps1 -Config ($Config | ConvertTo-Json)
            exit
        } else {
            [System.Windows.MessageBox]::Show("It looks like one of your files are invalid. Please check the file paths and try again.", "Invalid Data", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
})

$Window.FindName("InventoryTextBox").Add_TextChanged({ Test-Config })
$Window.FindName("ProfileTextBox").Add_TextChanged({ Test-Config })
$Window.FindName("ImagesTextBox").Add_TextChanged({ Test-Config })

$testPython = Test-PythonReq
if($null -eq $testPython) {
    [System.Windows.MessageBox]::Show("It looks like Python isn't installed on your system, or it isn't available in PATH. You'll need to install it (or set the PATH) before running this program.", "Python Not Installed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
} elseif ($testPython -ne $true) {
    [System.Windows.MessageBox]::Show("The following required Python libraries are missing: $($testPython -join ', '). You'll need to install them on your system using pip.", "Missing Libraries", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
}

$Window.ShowDialog()