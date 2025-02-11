# Barcode Manager (barcode.xaml) - Allows us to search for a barcode, view its data, and update/create new barcodes.

param (
    $Config
)

Add-Type -AssemblyName PresentationCore, PresentationFramework
$Window = $null
. "./assets/gui_func.ps1"
. "./assets/data_func.ps1"

try {
    $Config = $Config | ConvertFrom-Json

    if (-not ($Config -and $Config.Inventory -and $Config.Profile -and $Config.Images)) {
        Write-Error "The configuration file is missing required fields. Please ensure it includes your inventory.data file, profile.data file, and ProfileImages folder."
        exit
    }
} catch {
    Write-Error "An error occurred while processing your configuration. Please ensure it's formatted as a JSON file."
    exit
}

# ---- Initialize the Barcode Page ---- #
$Window = New-XamlWindow -XamlPath "./assets/pages/barcode.xaml"
$SearchBox = $Window.FindName("SearchBox")
$Placeholder = $Window.FindName("txtSearchPlaceholder")
$script:oldBarcode = $null

$Window.FindName("SearchButton").Add_Click({
    $barcode = [int]$SearchBox.Text
    $item = Get-BarcodeData -ArchivePath $Config.Inventory -Barcode $barcode

    if ($item) {
        $title = New-ProfileSearch -Query $item.TitleId -ProfileData $Config.Profile
        $titleSort = ($title | ConvertFrom-Json).sort_name
        $data = @()
        
        $script:oldBarcode = $barcode
        foreach ($key in $item.PSObject.Properties) {
            $data += [PSCustomObject]@{ Name = $key.Name; Value = $key.Value }
        }
        
        $Window.FindName("DataGrid").Visibility = "Visible"
        $Window.FindName("WaitingForSearch").Visibility = "Hidden"
        $Window.FindName("DataGrid").ItemsSource = $data
        $Window.FindName("TitleName").Content = "$titleSort"
        $Window.FindName("ConfirmButton").IsEnabled = $true
    } else {
        [System.Windows.MessageBox]::Show("An error occurred while looking up this barcode. It looks like it doesn't exist!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$Window.FindName("NewButton").Add_Click({
    $data = @()

    # Template of a new barcode (i know this is super low effort, but i kinda just want to get this done)
    $data += [PSCustomObject]@{ Name = "Barcode"; Value = "000000000" }
    $data += [PSCustomObject]@{ Name = "TitleId"; Value = "0000" }
    $data += [PSCustomObject]@{ Name = "Code"; Value = "Known" }
    $data += [PSCustomObject]@{ Name = "TotalRentalCount"; Value = "0" }
        
    $Window.FindName("DataGrid").Visibility = "Visible"
    $Window.FindName("WaitingForSearch").Visibility = "Hidden"
    $Window.FindName("DataGrid").ItemsSource = $data
    $Window.FindName("TitleName").Content = "Unknown Title"
    $Window.FindName("ConfirmButton").IsEnabled = $true
})

$Window.FindName("ConfirmButton").Add_Click({
    if($null -ne $Window.FindName("DataGrid").ItemsSource) {
        $newData = [PSCustomObject]@{}
        
        foreach ($row in $Window.FindName("DataGrid").ItemsSource) {
            $newData | Add-Member -MemberType NoteProperty -Name $row.Name -Value $row.Value
        }

        $newData.Code = Get-StatusCode -Code ($newData.Code.ToString()) # update the Code to be an integer

        if($script:oldBarcode -ne $newData.Barcode) {
            $barcodeExists = Get-BarcodeData -ArchivePath $Config.Inventory -Barcode $newData.Barcode

            if($null -eq $barcodeExists) {
                # Barcode doesn't exist, we're creating a new one
                $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to create a new barcode? This will not modify the existing selected barcode.", "Create Barcode", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                if($result -eq "Cancel") {
                    return
                }

                New-BarcodeData -ArchivePath $Config.Inventory -Barcode $newData.Barcode -TitleId $newData.TitleId -Code $newData.Code -TotalRentalCount $newData.TotalRentalCount
                [System.Windows.MessageBox]::Show("Your new barcode has been created successfully!", "Barcode Created", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } else {
                # They changed the barcode, but it already exists, so we're updating the existing one
                $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to update an existing barcode from the database? This will not modify the existing selected barcode.", "Create Barcode", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                if($result -eq "Cancel") {
                    return
                }

                Update-BarcodeData -ArchivePath $Config.Inventory -Barcode $newData.Barcode -TitleId $newData.TitleId -Code $newData.Code -TotalRentalCount $newData.TotalRentalCount
                [System.Windows.MessageBox]::Show("Your barcode has been updated successfully!", "Barcode Created", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        } else {
            # They didn't change the barcode, so we're updating the current one
            $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to overwrite this barcode data?", "Overwrite Warning", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
            if($result -eq "Cancel") {
                return
            }

            Update-BarcodeData -ArchivePath $Config.Inventory -Barcode $newData.Barcode -TitleId $newData.TitleId -Code $newData.Code -TotalRentalCount $newData.TotalRentalCount
            [System.Windows.MessageBox]::Show("Your barcode data has been updated successfully!", "Barcode Updated", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
})

$Window.FindName("TitleManagerButton").Add_Click({
    $Window.Close()
    .\title.ps1 -Config ($Config | ConvertTo-Json)
})

$SearchBox.add_TextChanged({
    if ($SearchBox.Text -eq "") {
        $Placeholder.Opacity = '0.5'
    } else {
        $Placeholder.Opacity = '0'
    }
})

$Window.ShowDialog()