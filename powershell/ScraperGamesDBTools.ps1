#*****************************************************************************************************************************************
#This is the PowerShell Script For Analyzing Scraped data
#
#For Now I need it to Move ByGameName 0 Count json search results. 
#Becuase it seems (USA) at end of search make some matches come back with zero results. Want to make it possible to match on more Titles.
#
#gamesdb Links
#https://thegamesdb.net/
#https://api.thegamesdb.net/#/
#v2019-11-17
#*****************************************************************************************************************************************


#*****************************************************************************************************************************************
#TO USE: set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************
#Local Paths
$global:ByGameName_Dir = "E:\Downloads\thegamesdb\Sony Playstation\ByGameName";
$global:ZeroMatches_Dir = "E:\Downloads\thegamesdb\Sony Playstation\ZeroMatches";

$global:Path2GamesMappingXML = "D:\_GAMES\RetroPI\30 CopyToRetroPie\RetroPie\roms\psx\theGamesdbMapping.xml";
$global:Path2GamesListXML = "D:\_GAMES\RetroPI\30 CopyToRetroPie\RetroPie\roms\psx\gamelist.xml"
# ****************************************************************************************************************************
# HANDLE ERROR
# ****************************************************************************************************************************
function HandleError([string] $ErrMsg)
{
    Write-Host -foregroundcolor red -backgroundcolor black $ErrMsg
    Exit #Stop Execution of the script
}



#*****************************************************************************************************************************************
#Iterate Game List json files
#Move those with 0 counts to ZeroMatches_Dir
#So we can try again with better search titles.
#*****************************************************************************************************************************************
function eraseZeroCountJSONFiles()
{
    Write-Host -foregroundcolor green -backgroundcolor black "processJSONFiles() $global:ByGameName_Dir"


    $FilesArr = get-childitem -Recurse -Path $global:ByGameName_Dir -include *.json
    Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " Games List  jsons"


    #Iterate Each json file in $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName

        Write-Host -foregroundcolor cyan -backgroundcolor black $fileTitle

        if (!(Test-Path -LiteralPath $FullName))
            {
                HandleError("$FullName does not exist") #If this happens signal problem!
                exit
            }

        $json = $null
        $json = Get-Content -LiteralPath $FullName | ConvertFrom-Json
        if ($json -eq $null)
        {
            HandleError "Unable to open results json file $FullName as json"
        }

        if ($json.data.games.length -eq 0)
        {
            Move-Item $FullName -Destination $global:ZeroMatches_Dir
        }

    }#END OF iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



   Write-Host -foregroundcolor green -backgroundcolor black "Leaving gamesDBMapping"
}

#*****************************************************************************************************************************************
#Erase all Negative ID Nodes From Games Mapping XML so we can try again to find matches
#*****************************************************************************************************************************************
function EraseNegativeIDs_From_gamesDBMapping_xml()
{
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesMappingXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }

    [System.Xml.XmlElement] $gameListNode = $xw.DocumentElement;

    Foreach($gameNode in $xw.gameList.game)
    {
        [string] $idStr = $gameNode.id;
        [int] $idINT = [int]$idStr;
        if ($idINT -lt 0)
        {
            Write-Host -foregroundcolor red -backgroundcolor black "Removed " $gameNode.path;
           #$gameListNode.RemoveChild($gameNode);
        }
    }#end of Foreach($gameNode in $xg.gameList.game)


    #Save Mapping XML with User Selections for Game ID's
    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
    $xw.Save($sw);
    $sw.Close();

return;
}

#*****************************************************************************************************************************************
#Copy Name from Mapping to Games List
#*****************************************************************************************************************************************
function mappingNames2gamesListNames()
{

    #Open Games Mapping
    [xml] $xr = $null
    $xr = Get-Content $global:Path2GamesMappingXML
    if ($xr -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }
    Write-Host -foregroundcolor green -backgroundcolor black $global:Path2GamesMappingXML "COUNT" $xr.gameList.game.Count

    #Create ht for Games Mapping
    $htgl_pathKeys = @{};
    Foreach($gn in $xr.gameList.game)
    {
        [int] $id = $gn.id;
        if ($id -gt 0)  #If less than zero match not found we have no data for this mapping
        {
            #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
            $pathStr =  $gn.path;
            if (!$htgl_pathKeys.ContainsKey($pathStr))
            {
                $htgl_pathKeys.Add($pathStr, $gn);
            }
            else
            {
                HandleError "Duplicate Path detected in GamesMappingXML.xml > $pathStr" 
            }
        }#end of if ($id -gt 0)

    }#end of Foreach($gameNode in $xg.gameList.game)


    [xml] $xg = $null
    $xg = Get-Content $global:Path2GamesListXML
    if ($xg -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Foreach($gameNode in $xg.gameList.game)
    {
        $path = [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path);
        
        if ($htgl_pathKeys.ContainsKey($path) -eq $true)
        {
            $mappingNode = $htgl_pathKeys[$path];
            $game_title = $mappingNode.game_title;
            $game_title=$game_title.trim();

            if ($game_title.length -gt 0)
            {
                Write-Host "Renaming from " $gameNode.name "to" $game_title;
                $gameNode.name=$game_title;
            }
            else
            {
                Write-Host $path "has no game title"
            }
        }
    }


    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesListXML, $false, $utf8)#2nd arg indicates append
    $xg.Save($sw);
    $sw.Close();
}

# ****************************************************************************************************************************
# SOT GAME NODES by path
# ****************************************************************************************************************************
function SortGameNodes([string] $path)
{
    #Open Results File as XML
    [xml] $xr = $null
    $xr = Get-Content $path

    

    if ($xr -eq $null)
    {
        HandleError "Unable to open results xml file $path as xml"
    }

    Write-Host -foregroundcolor green -backgroundcolor black $xr.gameList.game.Count " games in gameslist in SortGameNodes()"

    [xml] $xw = New-Object System.Xml.XmlDocument
    $gl_node = $xw.CreateElement("gameList")
    $xw.AppendChild($gl_node);

    #iterate each game Node in Sorted Order
    Foreach($gameNode in $xr.gameList.game | sort path)
    {
        $gamePath = $gameNode.Path
        $newNode = $xw.ImportNode($gameNode, $true)
        $gl_node.AppendChild($newNode)
    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($path, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black " Leaving SortGameNodes()"
}



#*****************************************************************************************************************************************
#Main Execution Begins Here
#*****************************************************************************************************************************************
Clear-Host

#eraseZeroCountJSONFiles
EraseNegativeIDs_From_gamesDBMapping_xml

#mappingNames2gamesListNames

#SortGameNodes $global:Path2GamesListXML
