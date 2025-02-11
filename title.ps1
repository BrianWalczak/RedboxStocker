# Title Manager (title.xaml) - Allows us to view and edit title data (including advanced updates) and also handles the title searching by name + id.

param (
    $Config
)

Add-Type -AssemblyName PresentationCore, PresentationFramework
$ProductTypes = @{}
$GenreTypes = @{}
$RatingTypes = @{}
$Window = $null
. "./assets/gui_func.ps1"
. "./assets/data_func.ps1"

try {
    $Config = $Config | ConvertFrom-Json

    if (-not ($Config -and $Config.Inventory -and $Config.Profile -and $Config.Images)) {
        Write-Error "The configuration file is missing required fields. Please ensure it includes your inventory.data file, profile.data file, and ProfileImages folder."
        exit
    }

    # Load product types
    $productCmd = New-VistaCommand -cmdToRun "SELECT Value FROM ProductType" -ProfileData $Config.Profile
    foreach($type in $productCmd) {
        $json = $type | ConvertFrom-Json
        $ProductTypes[[int]$json.product_type_id] = $json.product_type_name
    }

    # Load genre types
    $productCmd = New-VistaCommand -cmdToRun "SELECT Value FROM Genres" -ProfileData $Config.Profile
    foreach($type in $productCmd) {
        $json = $type | ConvertFrom-Json
        $GenreTypes[[int]$json.genre_id] = $json.genre_name
    }

    # Load rating types
    $productCmd = New-VistaCommand -cmdToRun "SELECT Value FROM ProductRating" -ProfileData $Config.Profile
    foreach($type in $productCmd) {
        $json = $type | ConvertFrom-Json
        $RatingTypes[[int]$json.rating_id] = $json.name
    }
} catch {
    Write-Error "An error occurred while processing your configuration. Please ensure it's formatted as a JSON file."
    exit
}

# ---- Initialize the Search Page ---- #

$Window = New-XamlWindow -XamlPath "./assets/pages/search.xaml"
$SearchBox = $Window.FindName("SearchBox")
$Placeholder = $Window.FindName("txtSearchPlaceholder")
$dataGrid = $window.FindName("DataGrid")
$searchButton = $window.FindName("SearchButton")
$openButton = $window.FindName("OpenButton")

$dataGridItems = New-Object System.Collections.ObjectModel.ObservableCollection[pscustomobject]
$dataGrid.ItemsSource = $dataGridItems

# we're using this function to insert the data into the barcode viewer
# "well why don't you just insert it without the need of this function?" - because it's also used to refresh the data in advanced
function New-DataInsert {
    param(
        $itemWindow,
        $titleData
    )

    # Clear the old data first if needed (which it is lol)
    $itemWindow.FindName("ChangesLabel").Visibility = "Hidden"
    $itemWindow.FindName("MediaTypeSelect").Items.Clear()
    $itemWindow.FindName("RatingSelect").Items.Clear()
    

    try { $itemWindow.FindName("TitleText").Text = $titleData.long_name } catch {}
    try { $itemWindow.FindName("SortNameText").Text = $titleData.sort_name } catch {}
    try { $itemWindow.FindName("DescriptionTextBox").Text = $titleData.description } catch {}
    try { $itemWindow.FindName("IDTitleBox").Text = $titleData.product_id } catch {}
    try { $itemWindow.FindName("RunTimeBox").Text = $titleData.running_time } catch {}
    try { $itemWindow.FindName("CoverImage").Source = $Config.Images + "/" + $titleData.image_file } catch {}
    try { $itemWindow.FindName("StudioBox").Text = $titleData.studio } catch {}

    # add all of the product types to the dropdown
    $sortedProd = $ProductTypes.Keys | Sort-Object
    foreach ($type in $sortedProd) {
        $newItem = New-Object PSObject -property @{
            Text  = $ProductTypes[$type]
            Value = $type.ToString()
        }

        $itemWindow.FindName("MediaTypeSelect").Items.Add($newItem)
    }

    # add all of the rating types to the dropdown
    $sortedRate = $RatingTypes.Keys | Sort-Object
    foreach ($type in $sortedRate) {
        $newItem = New-Object PSObject -property @{
            Text  = $RatingTypes[$type]
            Value = $type.ToString()
        }

        $itemWindow.FindName("RatingSelect").Items.Add($newItem)
    }

    $itemWindow.FindName("MediaTypeSelect").DisplayMemberPath = "Text"
    $itemWindow.FindName("MediaTypeSelect").SelectedValuePath = "Value"
    $itemWindow.FindName("MediaTypeSelect").SelectedValue = ($titleData.product_type_id).ToString()

    $itemWindow.FindName("RatingSelect").DisplayMemberPath = "Text"
    $itemWindow.FindName("RatingSelect").SelectedValuePath = "Value"
    $itemWindow.FindName("RatingSelect").SelectedValue = ($titleData.rating_id).ToString()
}
function OpenSelectedItem {
    $selectedItem = $dataGrid.SelectedItem
    if ($selectedItem) {
        $search = (New-ProfileSearch -Query $selectedItem.ID -ProfileData $Config.Profile)
        $titleData = $search | ConvertFrom-Json
        $itemWindow = New-XamlWindow -XamlPath "./assets/pages/title.xaml"

        New-DataInsert -itemWindow $itemWindow -titleData $titleData

        $itemWindow.FindName("StarringButton").Add_Click({
            $starWindow = New-XamlWindow -XamlPath "./assets/pages/starring.xaml"
            
            $inputBox = $starWindow.FindName("InputBox")
            $listBox = $starWindow.FindName("ListBox")
            
            $starWindow.FindName("AddButton").Add_Click({
                $text = $inputBox.Text.Trim()
                if (-not [string]::IsNullOrEmpty($text)) {
                    $listBox.Items.Add($text)
                    $inputBox.Clear()
                }
            })
            
            $starWindow.FindName("DeleteButton").Add_Click({
                if ($listBox.SelectedItem) {
                    $listBox.Items.Remove($listBox.SelectedItem)
                }
            })
            
            $starWindow.FindName("SaveButton").Add_Click({
                $titleData.starring = $listBox.Items

                $itemWindow.FindName("ChangesLabel").Visibility = "Visible"
                $starWindow.Close()
            })
            
            foreach($star in $titleData.starring) {
                $listBox.Items.Add($star.Trim())
            }
            
            $starWindow.ShowDialog()
        })

        $itemWindow.FindName("GenreButton").Add_Click({
            $genreWindow = New-XamlWindow -XamlPath "./assets/pages/genres.xaml"
            
            $checkboxPanel = $genreWindow.FindName("CheckboxPanel")
            $checkboxes = @()

            $genreWindow.FindName("UpdateButton").Add_Click({
                $newGenres = [PSCustomObject]@{}
                $checkboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object {
                    $newGenres | Add-Member -MemberType NoteProperty -Name ([int]$_.Tag) -Value $true
                }

                $titleData.genres = $newGenres
                $itemWindow.FindName("ChangesLabel").Visibility = "Visible"
                $genreWindow.Close()
            })

            $sortedGenre = $GenreTypes.Keys | Sort-Object
            foreach ($type in $sortedGenre) {
                $checkbox = New-Object System.Windows.Controls.CheckBox
                $checkbox.Content = $GenreTypes[$type]
                $checkbox.Tag = $type.ToString()
                $checkbox.Margin = [Windows.Thickness]::new(0, 5, 0, 0)

                if ($titleData.genres.$type -eq $true) {
                    $checkbox.IsChecked = $true
                }
                
                $checkboxPanel.Children.Add($checkbox)
                $checkboxes += $checkbox
            }

            $genreWindow.ShowDialog()
        })

        $itemWindow.FindName("EditImageButton").Add_Click({
            $result = Select-File -FileName "image" -Filter "Image files (*.jpg)|*.jpg"

            if($result) {
                $fileExists = Join-Path -Path $Config.Images -ChildPath (Split-Path -Path $result -Leaf)

                if (Test-Path $fileExists) {
                    $itemWindow.FindName("CoverImage").Source = $fileExists
                    $itemWindow.FindName("ChangesLabel").Visibility = "Visible"
                } else {
                    [System.Windows.MessageBox]::Show("Please select an image located in your ProfileImages folder.", "Invalid Image", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        })

        $itemWindow.FindName("AdvancedButton").Add_Click({
            $advWindow = New-XamlWindow -XamlPath "./assets/pages/advanced.xaml"
            
            $data = @()
            foreach ($key in $titleData.PSObject.Properties) {
                if($key.Value -is [string] -or $key.Value -is [int]) {
                    $data += [PSCustomObject]@{ Name = $key.Name; Value = $key.Value }
                }
            }
            
            $advWindow.FindName("DataGrid").ItemsSource = $data
            
            $advWindow.FindName("ConfirmButton").Add_Click({
                foreach ($row in $data) {
                    if($titleData.$($row.Name)) {
                        $titleData.$($row.Name) = $row.Value
                    }
                }

                New-DataInsert -itemWindow $itemWindow -titleData $titleData
                $itemWindow.FindName("ChangesLabel").Visibility = "Visible"
                $advWindow.Close()
            })

            $advWindow.ShowDialog()
        })

        $itemWindow.FindName("UpdateButton").Add_Click({
            $isNew = $false

            if($titleData.product_id -ne [int]($itemWindow.FindName("IDTitleBox").Text)) {
                $isNewCheck = New-VistaCommand -cmdToRun ("SELECT * FROM ProductCatalog WHERE [Key] = " + $itemWindow.FindName("IDTitleBox").Text) -ProfileData $Config.Profile

                if($isNewCheck) {
                    $result = [System.Windows.MessageBox]::Show("This will overwrite an existing title with the same product ID. Are you sure you want to continue?", "Overwrite Warning", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                    if($result -eq "Cancel") {
                        return
                    }

                    # delete the existing title id, cause it can cause conflicting records
                    New-VistaCommand -cmdToRun ("DELETE FROM ProductCatalog WHERE [Key] = " + $itemWindow.FindName("IDTitleBox").Text) -ProfileData $Config.Profile
                } else {
                    $isNew = $true
                    $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to create a new title under this product ID?", "Confirm Title", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                    if($result -eq "Cancel") {
                        return
                    }
                }
            } else {
                $result = [System.Windows.MessageBox]::Show("Are you sure you'd like to update this title?", "Overwrite Warning", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                if($result -eq "Cancel") {
                    return
                }
            }

            try { $titleData.long_name = [string]($itemWindow.FindName("TitleText").Text) } catch {}
            try { $titleData.sort_name = [string]($itemWindow.FindName("SortNameText").Text) } catch {}
            try { $titleData.description = [string]($itemWindow.FindName("DescriptionTextBox").Text) } catch {}
            try { $titleData.product_id = [int]($itemWindow.FindName("IDTitleBox").Text) } catch {}
            try { $titleData.running_time = [string]($itemWindow.FindName("RunTimeBox").Text) } catch {}
            try { $titleData.image_file = [string](Split-Path -Path $itemWindow.FindName("CoverImage").Source -Leaf) } catch {}
            try { $titleData.product_type_id = [int]($itemWindow.FindName("MediaTypeSelect").SelectedValue) } catch {}
            try { $titleData.studio = [string]($itemWindow.FindName("StudioBox").Text) } catch {}
            try { $titleData.rating_id = [int]($itemWindow.FindName("RatingSelect").SelectedValue) } catch {}

            $luaInputBase = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($titleData | ConvertTo-Json)))
            $command = "python -c `"from slpp import slpp as lua; import base64; import json; data = base64.b64decode('$luaInputBase').decode('utf-8'); print(lua.encode(json.loads(data)))`""

            $result = (Invoke-Expression $command | Out-String)

            # huge thanks to zach3697 for these:
            # Replacing single quotes with double single quotes
            $result = $result -replace "'", "''"
            # Removing brackets and quotes around variable names
            $result = $result -replace '\["', ""
            $result = $result -replace '"\]', ""
            # Removing new line and carriage returns
            $result = $result.Replace("`n", "").Replace("`r", "")
            # Replacing double tabs with a space
            $result = $result -replace "`t`t", " "
            # Replacing single tabs with a space
            $result = $result -replace "`t", " "

            # Regex pattern to wrap numeric keys within genres (added by Brian)
            # EDIT: fix for error on line 35 (data_func.ps1)
            $pattern = '(genres\s*=\s*{[^}]*?)(\d+)(\s*=\s*(true|false))'
            while ($result -match $pattern) {
                $result = $result -replace $pattern, '${1}[$2]${3}'
            }
            
            if($isNew) {
                $post = New-VistaUpdate -cmdToRun "INSERT INTO ProductCatalog (Key, Value) VALUES ('$($titleData.product_id)', '$($result)')" -ProfileData $Config.Profile

                if($post -eq 1) {
                    [System.Windows.MessageBox]::Show("The title has been created and updated successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                    $itemWindow.FindName("ChangesLabel").Visibility = "Hidden"
                } else {
                    [System.Windows.MessageBox]::Show("An error occurred while creating this title. Please try again later.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            } else {
                $post = New-VistaUpdate -cmdToRun "UPDATE ProductCatalog SET Value = '$($result)' WHERE [Key] = $($titleData.product_id)" -ProfileData $Config.Profile

                if($post -eq 1) {
                    [System.Windows.MessageBox]::Show("The title has been updated successfully and your changes have been saved.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                    $itemWindow.FindName("ChangesLabel").Visibility = "Hidden"
                } else {
                    [System.Windows.MessageBox]::Show("An error occurred while updating the item. Please try again.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        })

        $itemWindow.ShowDialog()
    }
}

$dataGrid.Add_SelectionChanged({
    if ($dataGrid.SelectedItem) {
        $openButton.IsEnabled = $true
    } else {
        $openButton.IsEnabled = $false
    }
})

$searchButton.Add_Click({
    $dataGridItems.Clear()
    $searchButton.IsEnabled = $false

    $search = New-ProfileSearch -Query $SearchBox.Text -ProfileData $Config.Profile
    foreach($item in $search) {
        try {
            $json = $item | ConvertFrom-Json
            $dataGridItems.Add([pscustomobject]@{ ID = $json.product_id; Title = $json.long_name; Format = $ProductTypes[$json.product_type_id] })
        } catch {
            [System.Windows.MessageBox]::Show("No results found for query '$($SearchBox.Text)'. Please refine your search for the best results.", "No Results Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }

    $searchButton.IsEnabled = $true
})

$dataGrid.Add_MouseDoubleClick({
    if ($dataGrid.SelectedItem -ne $null) {
        OpenSelectedItem
    }
})

$openButton.Add_Click({
    OpenSelectedItem
})

$SearchBox.add_TextChanged({
    if ($SearchBox.Text -eq "") {
        $Placeholder.Opacity = '0.5'
    } else {
        $Placeholder.Opacity = '0'
    }
})

$Window.FindName("BarcodeManagerButton").Add_Click({
    $Window.Close()
    .\barcode.ps1 -Config ($Config | ConvertTo-Json)
})

$Window.ShowDialog()