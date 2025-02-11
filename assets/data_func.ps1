# A collection of functions utilizing the VistaDB DLL and the ProductLookupCatalog DLL (to interact w/ inventory.data and profile.data).

Add-Type -Path "./assets/dll/VistaDB.NET20.dll"
Add-Type -Path "./assets/dll/Redbox.ProductLookupCatalog.dll"

# --- VistaDB Functions --- #

# Execute a command on the VistaDB database (SQL)
function New-VistaCommand {
    param (
        [string]$cmdToRun,
        [string]$ProfileData
    )

    $ErrorActionPreference = 'SilentlyContinue'

    $vistaConn = New-Object VistaDB.Provider.VistaDBConnection("Data Source=" + $ProfileData)
    $vistaConn.Open()
    $cmd = $vistaConn.CreateCommand()
    $cmd.CommandText = $cmdToRun

    $reader = $cmd.ExecuteReader()
    $received = @()

    while ($reader.Read()) { $received += $reader["Value"].ToString() }
    $vistaConn.Close()

    $ErrorActionPreference = 'Continue'

    # we have to parse the lua data as a JSON
    $luaParsed = @()
    foreach ($item in $received) {
        $luaInputBase = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($item)) # we're going to these lengths lol, we can't pass the input directly cause of special characters
        $command = "python -c `"from slpp import slpp as lua; import base64; import json; data = base64.b64decode('$luaInputBase').decode('utf-8'); print(json.dumps(lua.decode(data), indent=4))`"" # decode the base64 string and then parse it as lua
        # EDIT: this dumb library doesn't convert number strings in JSON such as "123" to [123] and rather 123 which is invalid syntax...

        $result = (Invoke-Expression $command | Out-String)
        $luaParsed += $result
    }
    
    return $luaParsed
}

# Update records w/ a command on the VistaDB database (SQL)
function New-VistaUpdate {
    param (
        [string]$cmdToRun,
        [string]$ProfileData
    )

    $ErrorActionPreference = 'SilentlyContinue'

    $vistaConn = New-Object VistaDB.Provider.VistaDBConnection("Data Source=" + $ProfileData)
    $vistaConn.Open()
    $cmd = $vistaConn.CreateCommand()
    $cmd.CommandText = $cmdToRun

    $reader = $cmd.ExecuteNonQuery()
    $vistaConn.Close()

    return $reader
}

# Search by a certain key in the VistaDB database
function New-ProfileSearch {
    param (
        [string]$Query,
        [string]$ProfileData
    )

    # Check if a title ID exists in the profile data for the given query
    $id_check = New-VistaCommand -cmdToRun ("SELECT * FROM ProductCatalog WHERE [Key] = " + $Query) -ProfileData $ProfileData

    if(-not $id_check) {
        # Probably wasn't a title ID, search for name instead
        $name_check = New-VistaCommand -cmdToRun "SELECT * FROM ProductCatalog WHERE LOWER(value) LIKE LOWER('%long_name%$($Query)%sort_name%');" -ProfileData $ProfileData

        if(-not $name_check) {
            Write-Output "No results found for query '$Query'."
        } else {
            return $name_check
        }
    } else {
        return $id_check
    }
}

# --- Inventory Functions --- #

# Get the barcode data from the archive (and convert to PSCustomObject... for native handling)
function Get-BarcodeData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$Barcode
    )

    try {
        $archive = [Redbox.ProductLookupCatalog.Archive]::Open($ArchivePath)
        $inventory = $archive.Find($Barcode)

        if ($inventory) {
            return [PSCustomObject]@{
                Barcode           = $inventory.Barcode
                TitleId          = $inventory.TitleId
                Code             = $inventory.Code
                TotalRentalCount = $inventory.TotalRentalCount
            }
        } else {
            Write-Warning "Barcode '$Barcode' not found in archive '$ArchivePath'."
            return $null
        }
    }
    catch {
        Write-Error "Error looking up barcode: $_"
        return $null
    }
    finally {
        if ($archive) { $archive.Dispose() }
    }
}

# Update the barcode data in the archive
function Update-BarcodeData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$Barcode,
        [Parameter(Mandatory = $false)]
        [string]$TitleId = $null,
        [Parameter(Mandatory = $false)]
        [int]$Code = $null,
        [Parameter(Mandatory = $false)]
        [int]$TotalRentalCount = $null
    )

    try {
        $archive = [Redbox.ProductLookupCatalog.Archive]::Open($ArchivePath, $false)
        $inventory = $archive.Find($Barcode)
        $index = $archive.FindIndex($Barcode)

        if ($inventory) {
            $inventory.TitleId = if ($null -ne $TitleId) { $TitleId } else { $inventory.TitleId }
            $inventory.Code = if ($null -ne $Code) { $Code } else { $inventory.Code }
            $inventory.TotalRentalCount = if ($null -ne $TotalRentalCount) { $TotalRentalCount } else { $inventory.TotalRentalCount }

            $archive.WriteInventory($index, $inventory) # this doesn't seem to write the changes to the archive
            $inventory | Format-List
        } else {
            Write-Warning "Barcode '$Barcode' not found in archive '$ArchivePath'."
            return $null
        }
    }
    catch {
        Write-Error "Error looking up barcode: $_"
        return $null
    }
    finally {
        if ($archive) { $archive.Dispose() }
    }
}

# Creates a new barcode in the archive and inserts appropriately
# code written by Viper33802 from the Redbox Tinkering Discord server, thanks Viper! :)
function New-BarcodeData
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$Barcode,
        [Parameter(Mandatory = $true)]
        [string]$TitleId,
        [Parameter(Mandatory = $false)]
        [int]$Code = 0,
        [Parameter(Mandatory = $false)]
        [int]$TotalRentalCount = 0,
        [Parameter(Mandatory = $false)]
        [int]$Sections = 8
    )

    try {
        $archive = [Redbox.ProductLookupCatalog.Archive]::Open($ArchivePath)
        $recordCount = $archive.Count

        if ($archive.Find($Barcode)) {
            throw "Barcode '$Barcode' already exists in the archive!"
        }

        $low = 0
        $high = $recordCount - 1

        while ($low -lt $high) {
            if ($high - $low -le 1) { break }

            $sectionSize = [Math]::Ceiling(($high - $low + 1) / $Sections)
            $sectionBoundaries = @()

            for ($i = 0; $i -lt $Sections; $i++) {
                $startIndex = $low + ($i * $sectionSize)
                $endIndex = [Math]::Min($startIndex + $sectionSize - 1, $high)

                if ($i -gt 0) { $startIndex = $sectionBoundaries[$i - 1].EndIndex }

                $sectionBoundaries += @{
                    StartIndex = $startIndex
                    EndIndex   = $endIndex
                }

                if ($endIndex -ge $high) { break }
            }

            $found = $false
            foreach ($section in $sectionBoundaries) {
                $sectionStartBarcode = $archive[$section.StartIndex].Barcode
                $sectionEndBarcode = $archive[$section.EndIndex].Barcode

                if ($Barcode -ge $sectionStartBarcode -and $Barcode -le $sectionEndBarcode) {
                    $low = $section.StartIndex
                    $high = $section.EndIndex
                    $found = $true
                    break
                }
            }

            if (-not $found) { throw "Unable to find a suitable range for the barcode '$Barcode'." }
        }

        $insertAt = $low
        for ($i = $low; $i -le $high; $i++) {
            if ($archive[$i].Barcode -gt $Barcode) {
                $insertAt = $i
                break
            }
        }

        $archive.Dispose()
        $archive = $null

        $fs = [System.IO.FileStream]::new($ArchivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $writer = [System.IO.BinaryWriter]::new($fs, [System.Text.ASCIIEncoding]::ASCII)
        
        $recordSize = 18
        $totalRecords = ($fs.Length - 312) / $recordSize

        if ($insertAt -lt $totalRecords) {
            $recordsToMove = $totalRecords - $insertAt
            $moveBufferSize = [Math]::Min($recordsToMove * $recordSize, 1MB)
            $remainingBytes = $recordsToMove * $recordSize
            $sourcePos = 312 + ($insertAt * $recordSize)

            while ($remainingBytes -gt 0) {
                $currentMoveSize = [Math]::Min($moveBufferSize, $remainingBytes)
                $moveBuffer = [byte[]]::new($currentMoveSize)
                
                $fs.Position = $sourcePos + $remainingBytes - $currentMoveSize
                [void]$fs.Read($moveBuffer, 0, $currentMoveSize)
                
                $fs.Position = $sourcePos + $remainingBytes - $currentMoveSize + $recordSize
                $fs.Write($moveBuffer, 0, $currentMoveSize)
                
                $remainingBytes -= $currentMoveSize
            }
        }

        $fs.Position = 312 + ($insertAt * $recordSize)
        $writer.Write([byte]0)
        $writer.Write([uint64]$Barcode)
        $writer.Write([uint32]$TitleId)
        $writer.Write([byte]$Code)
        $writer.Write([uint32]$TotalRentalCount)

        return $insertAt
    }
    catch {
        Write-Error "Error adding inventory record: $_"
        return $null
    }
    finally {
        if ($archive) { $archive.Dispose() }
        if ($writer) { $writer.Dispose() }
        if ($fs) { $fs.Dispose() }
    }
}

# Get the status of a barcode as an integer (basically gets the enum value of an InventoryStatusCode)
function Get-StatusCode {
    param(
        [Parameter(Mandatory = $true)]
        $Code
    )

    # check if $Code is a string
    if ($Code -is [string]) {
        $enum = [Redbox.ProductLookupCatalog.InventoryStatusCode]::$Code
        return [int]$enum
    }

    # check if $Code is an int
    if ($Code -is [int]) {
        return $Code
    }

    return $null
}