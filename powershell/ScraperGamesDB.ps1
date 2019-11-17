#*****************************************************************************************************************************************
#This is the PowerShell Script For Scraping Metadata from Gamesdb.net
#And putting into EmulationStation gameslist.xml
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
$global:Path2DownloadDir = "E:\Downloads\thegamesdb\"
$global:RegKeyStr = "HKCU:\SOFTWARE\retroPS_ScraperGamesDB"
$global:Path2RomsDir = "D:\_GAMES\RetroPI\30 CopyToRetroPie\RetroPie\roms\";

#gamesDBConfigs
$global:GamesDb_APIKey= "XXX"; 
$global:GamesDbBaseUrl = "https://api.thegamesdb.net/"

#*****************************************************************************************************************************************
#END OF To Use set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************

#Global Vars - Stored in Registry HKCU:\SOFTWARE\retroPS_ScraperGamesDB
$global:Path2GamesListXML = $null;
$global:PlatformStr = $null #User will choose now in GridView
$global:PlatformID = $null #User will choose now in GridView

#Global Vars
$global:Path2GamesMappingXML = $null;
$global:ht_APIGenres = $null;
$global:ht_APIDevelopers = $null;
$global:ht_APIPublishers = $null;


Class getGameNodeFromGamesListXMLResult
{
    [xml] $root = $null
    [System.Xml.XmlElement] $matching_game_node = $null
}


# ****************************************************************************************************************************
# HANDLE ERROR
# ****************************************************************************************************************************
function HandleError([string] $ErrMsg)
{
    Write-Host -foregroundcolor red -backgroundcolor black $ErrMsg
    Exit #Stop Execution of the script
}

# ****************************************************************************************************************************
# UI Select
#
# $selectionStr
# is the current selection
#
# $questionStr
# The question to display in Prompt to confirm Keep selectionStr
#
# $gridTitleStr
# Title to display in Grid View Selector if user wants new selection
#
# $gridOptions
# The rows of items to display in Grid View
#
# $propName
# Props Name to return In SelectioNStr
# ****************************************************************************************************************************
function uiSelect([string] $selectionStr, [string] $questionStr, [string] $gridTitleStr, $gridOptions, $propName)
{
    Write-Host -foregroundcolor green -backgroundcolor black "uiSelect() $selectionStr"

    $titleStr = $selectionStr;

    $msgBoxInput = [System.Windows.MessageBox]::Show($questionStr, $titleStr,"YesNoCancel","Question");

    if ($msgBoxInput -eq "Cancel")
    {
        HandleError "Cancelled, Quitting..."
    }

    if ($msgBoxInput -eq "Yes")
    {
        return $selectionStr;
    }

    #If here display GridView

    $xmlSel = $null;
    $xmlSel = $gridOptions | Out-GridView -OutputMode Single -Title $gridTitleStr;
    if ($xmlSel -eq $null)
    {
        HandleError "No Selection Made, Stopped";
    }

    #If here a selection was made!
    $selectionStr=$xmlSel.$propName;
    Write-Host -foregroundcolor cyan -backgroundcolor black "You selected $selectionStr;"
    return $selectionStr;
}


# ****************************************************************************************************************************
# Create Reg Keys to store some settings
# ****************************************************************************************************************************
function InitReg()
{
    Write-Host -foregroundcolor green -backgroundcolor black "InitReg()"
    $retVal = Test-Path -Path $global:RegKeyStr

     if ($retVal -eq $false)
     {
         New-Item -Path $global:RegKeyStr
         New-ItemProperty -Path $global:RegKeyStr -Name "PlatformStr" -Value ""
         New-ItemProperty -Path $global:RegKeyStr -Name "PlatformID" -Value ""
         New-ItemProperty -Path $global:RegKeyStr -Name "Path2GamesListXML" -Value ""
     }
     else
     {
        $global:PlatformStr = Get-ItemPropertyValue -Path $global:RegKeyStr -Name "PlatformStr"
        $global:PlatformID = Get-ItemPropertyValue -Path $global:RegKeyStr -Name "PlatformID"
        $global:Path2GamesListXML = Get-ItemPropertyValue -Path $global:RegKeyStr -Name "Path2GamesListXML"
     }
}


# ****************************************************************************************************************************
# Create Base Directorys if they don't already exist
# ****************************************************************************************************************************
function InitDirs()
{
    Write-Host -foregroundcolor green -backgroundcolor black "InitDirs() $global:PlatformStr"

    $TargetDir = $global:Path2DownloadDir + $global:PlatformStr + "\"
    $retVal = Test-Path -LiteralPath  $TargetDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetDir #Create the Dir
    }


    #Download All Images here
    $global:imageDir = $TargetDir + "m\"
    $retVal = Test-Path -LiteralPath  $global:imageDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $imageDir #Create the Dir
    }

    #Download All marquee here
    $marqueeDir = $global:imageDir + "marquee\";
    $retVal = Test-Path -LiteralPath  $marqueeDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $marqueeDir #Create the Dir
    }

    #Download All cover here
    $coverDir = $global:imageDir + "cover\";
    $retVal = Test-Path -LiteralPath  $coverDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $coverDir #Create the Dir
    }

    #Set global path for $global:Path2GamesMappingXML
    $romDir =Split-Path -Path $global:Path2GamesListXML
    $global:Path2GamesMappingXML = $romDir + "\theGamesdbMapping.xml";


    Set-Location -Path $TargetDir #Change Dir to Root of Platform Downloads Dir

    Write-Host -foregroundcolor green -backgroundcolor black "Scraper Downloading to:"
    Write-Host -foregroundcolor green -backgroundcolor black $TargetDir
    Write-Host "Leaving InitDirs()";


return;
}



# ****************************************************************************************************************************
#http://thegamesdb.net/api/GetPlatformsList.php
#Let user pick Platform so we can get Platform #
#Writes selection to registry
# ****************************************************************************************************************************
function AksUserPlatform()
{
    Write-Host -foregroundcolor green -backgroundcolor black "AksUserPlatform() $global:PlatformStr"

    $url = $global:GamesDbBaseUrl + "Platforms?apikey=" + $global:GamesDb_APIKey;

    $retVal = Test-Path -LiteralPath  $global:Path2DownloadDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetDir #Create the Dir
    }
    
    $TargetFile = $global:Path2DownloadDir + "Platforms.json"
    
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        #Only Download if NOT already there
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }

    #Now Open Platforms.xml
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }

    # Convert the PSCustomObject back to a hashtable
    $ht_Platforms = @{} #HashTable
    $json.data.platforms.psobject.properties | Foreach { $ht_Platforms[$_.Name] = $_.Value }

    #Prompt User For Selection
    [string] $selectionStr = $global:PlatformID;
    [string] $questionStr = "Is your platform still $PlatformStr" + "?";
    [string] $gridTitleStr = "Select Platform or cancel to quit";
    [string] $propName = "id";

    #$global:PlatformStr = uiSelect $selectionStr $questionStr $gridTitleStr $ht_Platforms.Values $propName
    $global:PlatformID = uiSelect $selectionStr $questionStr $gridTitleStr $ht_Platforms.Values $propName
    $global:PlatformStr = $ht_Platforms[$global:PlatformID].name;#Get Name back from Hash Table based on ID

    #Write back to Registry Now
    Set-ItemProperty -Path $global:RegKeyStr -Name "PlatformID" -Value $global:PlatformID
    Set-ItemProperty -Path $global:RegKeyStr -Name "PlatformStr" -Value $global:PlatformStr

    return;
}

# ****************************************************************************************************************************
#Ask User to pick specific gameslist.xml out of roms folder. 
#Saves setting in registry
# ****************************************************************************************************************************
function AskUserGamesListXML
{
    Write-Host -foregroundcolor green -backgroundcolor black "AskUserGamesListXML() $global:Path2GamesListXML"

   #Now lets get list of zip files in Console Dir
   $FilesArr = get-childitem -Recurse -Path $global:Path2RomsDir -include *.xml
   
   [xml] $xw = New-Object System.Xml.XmlDocument
   $files_node = $xw.CreateElement("files")
   $xw.AppendChild($files_node);

    foreach($file in $FilesArr)
    {
        $f_node = $xw.CreateElement("file")
        
        #parentDir
        $node = $xw.CreateElement("platform")
        $node.InnerText = [System.IO.Path]::GetFileNameWithoutExtension($file.Directory);
        $f_node.AppendChild($node);

        #name Node
        $node = $xw.CreateElement("path")
        $node.InnerText = $file.FullName;
        $f_node.AppendChild($node);

        $files_node.AppendChild($f_node);
    
    }#end of foreach($file in $FilesArr)



    #Prompt User For Selection
    [string] $selectionStr = $global:Path2GamesListXML;
    [string] $questionStr = "Is your gamesList.xml still $selectionStr" + "?";
    [string] $gridTitleStr = "Select gamesList.xml or cancel to quit";
    [string] $propName = "path";

    $global:Path2GamesListXML = uiSelect $selectionStr $questionStr $gridTitleStr $xw.files.file $propName
    Set-ItemProperty -Path $global:RegKeyStr -Name "Path2GamesListXML" -Value $global:Path2GamesListXML

    return;
}


# ****************************************************************************************************************************
# Creates the theGamesdbMapping.xml if it doesn't already exist
# TODO: Open games list.xml add and remove nodes based on some key value for now it is path title.
# ****************************************************************************************************************************
function gamesDBMapping_Maintenance()
{
    Write-Host -foregroundcolor cyan -backgroundcolor black "Starting gamesDBMapping_Maintenance()"

    #Does mapping xml exist yet? If not create empty mapping xml file
    $retVal = Test-Path -LiteralPath  $global:Path2GamesMappingXML -PathType Leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
       [xml] $xw = New-Object System.Xml.XmlDocument
       $gameList_node = $xw.CreateElement("gameList")
       $xw.AppendChild($gameList_node);
       $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
       $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
       $xw.Save($sw);
       $sw.Close();
    }

    #Lets do some validation on mapping xml next. Open it.
    [xml] $xwm = $null
    $xwm = Get-Content $global:Path2GamesMappingXML
    if ($xwm -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }
    
    #Verify Path Keys are Unique in mapping.xml (No Duplicate Keys)
    $htmp_pathKeys = @{}
    Foreach($gameNode in $xwm.gameList.game)
    {
        $path = $gameNode.path;
        if (!$htmp_pathKeys.ContainsKey($path))
        {
            $htmp_pathKeys.Add($path, $gameNode);
        }
        else
        {
            #$xwm.gameList.RemoveChild($gameNode);
            HandleError "Duplicate Path detected in theGamesdbMapping.xml > $path" 
        }
    }

    #Create HT of Path Keys in gameslist.xml to check for removals. HT must be used or way to slow!!!!
    [xml] $xg = $null
    $xg = Get-Content $global:Path2GamesListXML
    if ($xg -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor green -backgroundcolor black $global:Path2GamesMappingXML "COUNT" $xwm.gameList.game.Count
    Write-Host -foregroundcolor green -backgroundcolor black $global:Path2GamesListXML "COUNT" $xg.gameList.game.Count

    if ($xwm.gameList.game.count -ne $xg.gameList.game.Count)
    {
        Write-Host -foregroundcolor red -backgroundcolor black "Counts do not match"
    }

    $htgl_pathKeys = @{};
    Foreach($gn in $xg.gameList.game)
    {
        #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
        $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gn.path)
        if (!$htgl_pathKeys.ContainsKey($pathStr))
        {
            $htgl_pathKeys.Add($pathStr, $gn);
        }
        else
        {
            HandleError "Duplicate Path detected in gameslist.xml > $pathStr" 
        }

    }#end of Foreach($gameNode in $xg.gameList.game)



    Write-Host -foregroundcolor green -backgroundcolor black "Please wait, Checking for deletes in gameslist.xml"

    #iterate each mapping game Node and delete if missing from gameslist.xml (manually deleted from gameslist.xml)
    Foreach($gameNode in $xwm.gameList.game)
    {
        $path = $gameNode.path;
        
        if (!$htgl_pathKeys.ContainsKey($path))
        {
          Write-Host -foregroundcolor red -backgroundcolor black "Removal Detected in gameslist.xml" $gameNode.path;
          $xwm.gameList.RemoveChild($gameNode);
          Write-Host -foregroundcolor red -backgroundcolor black "Removed corresponding node from GamesMappingXML";
        }
    }

    #iterate each gamslist game Node and add if missing from mapping.xml (newly added to gameslist.xml or first run)
    Foreach($gn in $xg.gameList.game)
    {
        #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
        $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gn.path)
        if (!$htmp_pathKeys.ContainsKey($pathStr))
        {
            Write-Host -foregroundcolor red -backgroundcolor black "Nodie in gameslist.xml not in mapping" $pathStr;
            [System.Xml.XmlElement] $new_game_node = $xwm.CreateElement("game")
            $xwm.DocumentElement.AppendChild($new_game_node);

            #path Node
            $node = $xwm.CreateElement("path")
            $node.InnerText = $pathStr;
            $new_game_node.AppendChild($node);

            
        }
    }#end of Foreach($gameNode in $xg.gameList.game)


    Write-Host -foregroundcolor red -backgroundcolor black "Determing Processing"
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    #Iterate each mapping game Node and Determine Processing Needed for each Node. 
    #The mapping file will now have knowledge of what is needed, so we can drive processing from it.
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    Foreach($gn in $xwm.gameList.game)
    {
        $path = $gn.path;
        #if ($path -eq "XXX")
        #{
            #$T="";
        #}

        Write-Host -foregroundcolor yellow -backgroundcolor black $path

        #Get Corresponding games list game node
        $gameNode = $htgl_pathKeys[$path];

        #genre
        $genre=$gameNode.genre;
        if ($genre.length -eq 0)
        {
            addNeedsMetadataNode $gn "genre"
        }
        else
        {
            removeNeedsMetadataNode $gn "genre"
        }

        #desc
        $desc=$gameNode.desc;
        if ($desc.length -eq 0)
        {
            addNeedsMetadataNode $gn "desc"
        }
        else
        {
            removeNeedsMetadataNode $gn "desc"
        }

        #publisher
        $publisher=$gameNode.publisher;
        if ($publisher.length -eq 0)
        {
            addNeedsMetadataNode $gn "publisher"
        }
        else
        {
            removeNeedsMetadataNode $gn "publisher"
        }

        #developer
        $developer=$gameNode.developer;
        if ($developer.length -eq 0)
        {
            addNeedsMetadataNode $gn "developer"
        }
        else
        {
            removeNeedsMetadataNode $gn "developer"
        }

        #releasedate
        $releasedate=$gameNode.releasedate;
        if ($releasedate.length -eq 0)
        {
            addNeedsMetadataNode $gn "releasedate"
        }
        else
        {
            removeNeedsMetadataNode $gn "releasedate"
        }

        #players
        $players=$gameNode.players;
        if ($players.length -eq 0)
        {
            addNeedsMetadataNode $gn "players"
        }
        else
        {
            removeNeedsMetadataNode $gn "players"
        }

        #video
        $video=$gameNode.video;
        if ($video.length -eq 0)
        {
            addNeedsMediaNode $gn "video"
        }
        else
        {
            removeNeedsMediaNode $gn "video"
        }

        #marquee
        $marquee=$gameNode.marquee;
        if ($marquee.length -eq 0)
        {
            addNeedsMediaNode $gn "marquee"
        }
        else
        {
            removeNeedsMediaNode $gn "marquee"
        }

        #image
        $image=$gameNode.image;
        if ($image.length -eq 0)
        {
            addNeedsMediaNode $gn "image"
        }
        else
        {
            removeNeedsMediaNode $gn "image"
        }


    }#end of Foreach($gn in $xwm.gameList.game)


    #Save Path2GamesMappingXML
    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
    $xwm.Save($sw);
    $sw.Close();


    Write-Host -foregroundcolor cyan -backgroundcolor black "Leaving gamesDBMapping_Maintenance()"

return;
}

#*********************************************************************************************************
#Add Needs MetaData Node. If already exists does nothing.
#*********************************************************************************************************
function addNeedsMetadataNode([System.Xml.XmlNode] $gn, [string] $name)
{
    [System.Xml.XmlNode] $needsNode = $gn.SelectSingleNode("needs");

    if ($needsNode -eq $null)
    {
        $needsNode = $gn.OwnerDocument.CreateElement("needs")
        $gn.AppendChild($needsNode);
    }
    
    [System.Xml.XmlNode] $metadataNode = $needsNode.SelectSingleNode("metadata");

    if ($metadataNode -eq $null)
    {
        $metadataNode = $gn.OwnerDocument.CreateElement("metadata")
        $needsNode.AppendChild($metadataNode);
    }

    

    if ($metadataNode.HasAttribute($name) -eq $false)
    {
        $attrib = $metadataNode.OwnerDocument.CreateAttribute($name);
        $metadataNode.Attributes.Append($attrib);
    }


    return;
}

#*********************************************************************************************************
#Removes Needs MetaData Node. If already doesn't exist does nothing.
#*********************************************************************************************************
function removeNeedsMetadataNode([System.Xml.XmlNode] $gn, [string] $name)
{
    [System.Xml.XmlNode] $needsNode = $gn.SelectSingleNode("needs");
    if ($needsNode -eq $null)
    {
        return;
    }
    
    [System.Xml.XmlNode] $metadataNode = $needsNode.SelectSingleNode("metadata");
    if ($metadataNode -eq $null)
    {
        return;
    }


    if ($metadataNode.HasAttribute($name) -eq $false)
    {
        return;
    }

    $attrib = $metadataNode.Attributes[$name];
    $metadataNode.Attributes.Remove($attrib);

    if ($metadataNode.Attributes.Count -eq 0)
    {
        $needsNode.RemoveChild($metadataNode);
    }

    if ($needsNode.HasChildNodes -eq $false)
    {
        $gn.RemoveChild($needsNode);
    }

    return;
}


#*********************************************************************************************************
#Add Needs MetaData Node. If already exists does nothing.
#*********************************************************************************************************
function addNeedsMediaNode([System.Xml.XmlNode] $gn, [string] $name)
{
    [System.Xml.XmlNode] $needsNode = $gn.SelectSingleNode("needs");

    if ($needsNode -eq $null)
    {
        $needsNode = $gn.OwnerDocument.CreateElement("needs")
        $gn.AppendChild($needsNode);
    }
    
    [System.Xml.XmlNode] $mediaNode = $needsNode.SelectSingleNode("media");

    if ($mediaNode -eq $null)
    {
        $mediaNode = $gn.OwnerDocument.CreateElement("media")
        $needsNode.AppendChild($mediaNode);
    }

    

    if ($mediaNode.HasAttribute($name) -eq $false)
    {
        $attrib = $mediaNode.OwnerDocument.CreateAttribute($name);
        $mediaNode.Attributes.Append($attrib);
    }


    return;
}

#*********************************************************************************************************
#Removes Needs MetaData Node. If already doesn't exist does nothing.
#*********************************************************************************************************
function removeNeedsMediaNode([System.Xml.XmlNode] $gn, [string] $name)
{
    [System.Xml.XmlNode] $needsNode = $gn.SelectSingleNode("needs");
    if ($needsNode -eq $null)
    {
        return;
    }
    
    [System.Xml.XmlNode] $mediaNode = $needsNode.SelectSingleNode("media");
    if ($mediaNode -eq $null)
    {
        return;
    }


    if ($mediaNode.HasAttribute($name) -eq $false)
    {
        return;
    }

    $attrib = $mediaNode.Attributes[$name];
    $mediaNode.Attributes.Remove($attrib);


    if ($mediaNode.Attributes.Count -eq 0)
    {
        $needsNode.RemoveChild($mediaNode);
    }

    if ($needsNode.HasChildNodes -eq $false)
    {
        $gn.RemoveChild($needsNode);
    }

    return;
}



#*********************************************************************************************************
#Scans GamesList XML for a gameNode matching Game File Path
#*********************************************************************************************************
function getGameNodeFromGamesListXML([string] $path)
{
    $result = New-Object getGameNodeFromGamesListXMLResult;

    [xml] $xg = $null
    $xg = Get-Content $global:Path2GamesListXML
    if ($xg -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }
    
    $result.root=$xg;

    $matching_game_node = $null;
    Foreach($gn in $xg.gameList.game)
    {
        #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
        $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gn.path)
        if ($pathStr -eq $path)
        {
            $result.matching_game_node=$gn;
            return $result;
        }
    }#end of Foreach($gameNode in $xg.gameList.game)

    return $null;
}


#sample
#https://api.thegamesdb.net/Games/ByGameName?apikey=1&name=XXX&filter%5Bplatform%5D=##
# ****************************************************************************************************************************
#Pass a Game Name to return list of possible game matches
#Writes web page response file to $global:Path2DownloadDir\ ByGameName ONLY if it does not already exist there.
#$PathStr is the Path Value from GamesList.Xml game node. That is the Key back into the gameslist.xml (Not the Name)
# ****************************************************************************************************************************
function APIGetGameList([string] $gameName, [string] $pathStr)
{
    Write-Host -foregroundcolor green -backgroundcolor black "APIGetGameList() $gameName : $global:PlatformStr"

    
    #Remove (USA), (Japan), (Europe), these often causes games db api to come back with zero matches
    $searchTerm = [Regex]::Replace($gameName, [regex]::Escape("(USA)"), "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
    $searchTerm = [Regex]::Replace($searchTerm, [regex]::Escape("(Japan)"), "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
    $searchTerm = [Regex]::Replace($searchTerm, [regex]::Escape("(Europe)"), "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase);
    
    


    $url = $global:GamesDbBaseUrl + "Games/ByGameName?apikey=" + $global:GamesDb_APIKey + "&name=" + $searchTerm + "&filter%5Bplatform%5D=" + $global:PlatformID

    Write-Host $url

    $TargetDir = $global:Path2DownloadDir + $global:PlatformStr +"\ByGameName\"

    $retVal = Test-Path -LiteralPath  $TargetDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetDir #Create the Dir
    }
    
    $TargetFile = "$TargetDir$pathStr.json"
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile


    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $true)
    {
        Write-Host "$pathStr already exists" -foregroundcolor red
        return;
    }

    Write-Host -foregroundcolor cyan -backgroundcolor black $url
    $webclient = new-object System.Net.WebClient
    $webclient.DownloadFile($url, $TargetFile)
    
    return;
}

#sample
#https://api.thegamesdb.net/Games/ByGameID?apikey=1&id=1
# ****************************************************************************************************************************
#Pass a GameNode from theGamesdbMapping.xml
#
#Writes web page response json file to $global:Path2DownloadDir\ByGameID ONLY if it does not already exist there.
#Also downloads Image ScreenShot and ClearLogo for Marquee
# ****************************************************************************************************************************
function API_GetGameByGameID([System.Xml.XmlElement] $gameNode)
{
    $path = $gameNode.path;
    $id=$gameNode.id;

    Write-Host -foregroundcolor yellow -backgroundcolor black "API_GetGameByGameID: $path"
    $url = $global:GamesDbBaseUrl + "Games/ByGameID?apikey=" + $global:GamesDb_APIKey + "&id=" + $id
    #We Need desc, releasedate, developer, publisher, genre, players, rating
    $url = $url + "&fields=players%2Cpublishers%2Cgenres%2Coverview";
    Write-Host $url

    $TargetGameDir = $global:Path2DownloadDir + $global:PlatformStr +"\ByGameID\" + $path+ "\";

    $retVal = Test-Path -LiteralPath  $TargetGameDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetGameDir #Create the Dir
    }
    
    $TargetFile = $TargetGameDir + $id +".json";
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    #DOWNLOAD GAME FILE FROM GAMES DB IF NOT ALREADY THERE>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -ne $true)
    {
        #If here Download The Game List File
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }
    else
    {
        Write-Host "$gameID already exists" -foregroundcolor green
    }

    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    #JSON GAME METADATA
    #Lets Open the JSON GAME Metadata File From Games DB .NET .....................................
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }

    $jsonGame = $json.data.games[0];#Should be only one game!

    # READS
    $json_game_title = makeASCIIStr $jsonGame.game_title;
    $descStr = $jsonGame.overview;#Strip out Foreign Chars
    $json_asciiDescStr = makeASCIIStr $descStr

    [string] $genre_KeyStr = "";
    if ($jsonGame.genres.length -gt 0)
    {
        $genre_KeyStr = $jsonGame.genres[0];
    }

    [string] $json_genreStr = "";
    if ($genre_KeyStr.Length -gt 0)
    {
        $json_genreStr = $global:ht_APIGenres[$genre_KeyStr].name;
    }

    [string] $json_releaseDate = $null;
    $json_releaseDate = $jsonGame.release_date;
    if ($json_releaseDate -ne $null)
    {
        if ($json_releaseDate.Length -gt 0)
        {
            [DateTime] $dt = [DateTime] $json_releaseDate;
            $json_releaseDate = $dt.ToString("yyyyMMddT000000");
        }
    }

    [string] $json_players = "";
    if ($jsonGame.players -ne $null)
    {
        [string] $json_players = $jsonGame.players;
    }


    [string] $publisher_KeyStr = "";
    if ($jsonGame.publishers.length -gt 0)
    {
        $publisher_KeyStr = $jsonGame.publishers[0];
    }

    [string] $json_publisherStr = "";
    if ($publisher_KeyStr.Length -gt 0)
    {
        $json_publisherStr= $global:ht_APIPublishers[$publisher_KeyStr].name;
        $json_publisherStr = makeASCIIStr $json_publisherStr;
    }
    

    [string] $devloper_KeyStr = "";
    if ($jsonGame.developer.length -gt 0)
    {
        $devloper_KeyStr = $jsonGame.developers[0];
    }

    [string] $json_developerStr = "";
    if ($devloper_KeyStr.Length -gt 0)
    {
        $json_developerStr= $global:ht_APIDevelopers[$devloper_KeyStr].name;
        $json_developerStr = makeASCIIStr $json_developerStr;
    }

    


    Write-Host -foregroundcolor green -backgroundcolor black "Title: $json_game_title"
    Write-Host -foregroundcolor green -backgroundcolor black "Genre: $json_genreStr"
    Write-Host -foregroundcolor green -backgroundcolor black "Release Date: $json_releaseDate"
    Write-Host -foregroundcolor green -backgroundcolor black "Players: $json_players"
    Write-Host -foregroundcolor green -backgroundcolor black "Publisher: $json_publisherStr"
    Write-Host -foregroundcolor green -backgroundcolor black "Developer: $json_developerStr"

    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #Open Target RetroPI GamesList.xml so we can edit >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    #First Make a backup copy from BEFORE our EDITS and put in game dir. This way we can always ROLLBACK if something goes wrong.
    Copy-Item -LiteralPath $global:Path2GamesListXML -Destination $TargetGameDir

    $result = getGameNodeFromGamesListXML $gameNode.path;
    if ($result -eq $null)
    {
        Write-Host $path
        HandleError "Unable to find matching game node in games.xml"
    }
    $matching_game_node=$result.matching_game_node;

    #If we are here we have the game node to edit

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #META DATA PROCESSING
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #name node
    
    #if ($json_game_title.length -gt 0)
    #{   #Not so sure I want to use this
     #   $matching_game_node.name = $json_game_title;
    #}

    #desc Node
    if ($matching_game_node.desc.count -lt 1) #Only Add if not there
    {
        $node = $result.root.CreateElement("desc")
        $matching_game_node.AppendChild($node);
    }

    if ($matching_game_node.desc.length -eq 0)
    {
        $matching_game_node.desc = $json_asciiDescStr;
    }


    #genre Node
    if ($json_genreStr.Length -gt 0)
    {
        if ($matching_game_node.genre.count -lt 1)
        {#Only Add if not there
            Write-Host -foregroundcolor red -backgroundcolor black "genreStr: $genreStr"
            $node = $result.root.CreateElement("genre")
            $matching_game_node.AppendChild($node);
        }

        if ($matching_game_node.genre.length -eq 0)
        {
            $matching_game_node.genre = $json_genreStr;
        }
    }


    

    #releasedate
    if ($json_releaseDate.Length -gt 0)
    {
        if ($matching_game_node.releasedate.count -lt 1)
        {#Only Add if not there
            $node = $result.root.CreateElement("releasedate")
            $matching_game_node.AppendChild($node);
        }

        if ($matching_game_node.releasedate.length -eq 0)
        {
            $matching_game_node.releasedate = $json_releaseDate;
        }
    }


    #players
    if ($matching_game_node.players.count -lt 1)
    {#Only Add if not there
        if ($json_players.length -gt 0)
        {
            $node = $result.root.CreateElement("players")
            $matching_game_node.AppendChild($node);
        }
    }

    if ($matching_game_node.players.length -eq 0 -and $json_players.length -gt 0)
    {
        $matching_game_node.players = $json_players;
    }



    #publisher


    if ($json_publisherStr.Length -gt 0)
    {
        if ($matching_game_node.publisher.count -lt 1)
        {#Only Add if not there
            $node = $result.root.CreateElement("publisher")
            $matching_game_node.AppendChild($node);
        }

        $matching_game_node.publisher = $json_publisherStr;
    }

    #developer

    if ($json_developerStr.Length -gt 0)
    {
        if ($matching_game_node.developer.count -lt 1)
        {#Only Add if not there
            $node = $result.root.CreateElement("developer")
            $matching_game_node.AppendChild($node);
        }

        $matching_game_node.developer = $json_developerStr;
    }


    #Write a GameNode in Games.xml Format In this Dir as If we were going to copy and paste it, so we can view on it's own.
    saveLocalGamesXML $TargetGameDir $matching_game_node

    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesListXML, $false, $utf8)#2nd arg indicates append
    $result.root.Save($sw);
    $sw.Close();

    return;
}

# ****************************************************************************************************************************
#SAVE LOCAL GAMES XML
#Save Local Games.xml with converted xml data.
# screenShotFname  can be zero length string if NOT supplied
# marqueeFname can be zero length string if not supplied
# ****************************************************************************************************************************
function saveLocalGamesXML([string] $TargetGameDir, [System.XML.XmLElement] $gn)
{
    Write-Host -foregroundcolor green -backgroundcolor black "saveLocalGamesXML()"

    #Write a GameNode in Games.xml Format In this Dir as If we were going to copy and paste it, so we can view on it's own.
    [xml] $xw = New-Object System.Xml.XmlDocument
    [System.XML.XmLElement] $game_node = $xw.CreateElement("game")
    $xw.AppendChild($game_node);

    #desc Node
    [System.XML.XmLElement] $node = $xw.CreateElement("desc")
    $node.InnerText = $gn.desc;
    $game_node.AppendChild($node);
    
    #genre
    [System.XML.XmLElement] $node = $xw.CreateElement("genre")
    $node.InnerText = $gn.genre;
    $game_node.AppendChild($node);

    #releasedate
    [System.XML.XmLElement] $node = $xw.CreateElement("releasedate")
    $node.InnerText = $gn.releasedate;
    $game_node.AppendChild($node);


    #players
    [System.XML.XmLElement] $node = $xw.CreateElement("players")
    $node.InnerText = $gn.Players;
    $game_node.AppendChild($node);

    #publisher
    [System.XML.XmLElement] $node = $xw.CreateElement("publisher")
    $node.InnerText = $gn.publisher;
    $game_node.AppendChild($node);
    
    #devloper
    [System.XML.XmLElement] $node = $xw.CreateElement("developer")
    $node.InnerText = $gn.developer;
    $game_node.AppendChild($node);

    $TargetFile = $TargetGameDir + "game.xml"
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($TargetFile, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

    return;
}



#sample
#https://api.thegamesdb.net/Games/Images?apikey=1&games_id=1
# ****************************************************************************************************************************
#Pass a GameNode from  theGamesdbMapping.xml
#
#Writes web page response json file to $global:Path2DownloadDir\Images ONLY if it does not already exist there.
#Also downloads Image ScreenShot and ClearLogo for Marquee
# ****************************************************************************************************************************
function API_GetGameImages([System.Xml.XmlElement] $gameNode)
{
    $path = $gameNode.path;
    $id=$gameNode.id;

    Write-Host -foregroundcolor yellow -backgroundcolor black "API_GetGameImages: $path"
    $url = $global:GamesDbBaseUrl + "Games/Images?apikey=" + $global:GamesDb_APIKey + "&games_id=" + $id
    Write-Host $url

    $TargetGameDir = $global:Path2DownloadDir + $global:PlatformStr +"\Images\" + $path+ "\";

    $retVal = Test-Path -LiteralPath  $TargetGameDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetGameDir #Create the Dir
    }
    
    $TargetFile = $TargetGameDir + $id +".json";
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    #DOWNLOAD GAME FILE FROM GAMES DB IF NOT ALREADY THERE>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -ne $true)
    {
        #If here Download The Game List File
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }
    else
    {
        Write-Host "$gameID already exists" -foregroundcolor green
    }




    #Lets Open the JSON GAME File From Games DB .NET .....................................
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }

    #Lets try to get to the json data we want
    $jsonImages = $json.data.images;#Should be only one game!
    $nameSubProp = $jsonImages.psobject.properties.Name;#GameID? Should not have to write code like this but oh well.
    $imgsArrJSON = $jsonImages.$nameSubProp;

    $baseImgURL = $json.data.base_url.original;


    #Open Target RetroPI GamesList.xml so we can edit >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $result = getGameNodeFromGamesListXML $gameNode.path;
    if ($result -eq $null)
    {
        Write-Host $path
        HandleError "Unable to find matching game node in games.xml"
    }
    $matching_game_node=$result.matching_game_node;

    #If we are here we have the game node to edit


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #MARQUEE PROCESSING 
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    #Download  clearlogo (We can use as Marquee) >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $marqueeFname = "";#Blank String indicates NONE or Not needed
    if ($matching_game_node.marquee.count -lt 1)
    {
        $clearLogo = $null;
        foreach ($img in $imgsArrJSON)
        {
            if ($img.type -eq "clearlogo")
            {
                $clearLogo=$img;
                break;
            }
        }


        if ($clearLogo -ne $null)
        {
            $LogoURL = $baseImgURL+$clearLogo.filename;
            $extension = [System.IO.Path]::GetExtension($LogoURL);
    
            $marqueeFname = $path + $extension;
            $TargetFile = $global:imageDir + "marquee\"+ $marqueeFname;

            $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
            if ($retVal -ne $true)
            {
                #If here Download The Game List File
                Write-Host "SOURCE"
                Write-Host -foregroundcolor cyan -backgroundcolor black $LogoURL
                Write-Host "TARGET"
                Write-Host -foregroundcolor cyan -backgroundcolor black $TargetFile
                $webclient = new-object System.Net.WebClient
                $webclient.DownloadFile($LogoURL, $TargetFile)
            }
        }#end of if ($clearLogo -ne $null)
    }


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #SCREEN IMAGE PROCESSING 
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    #Download  clearlogo (We can use as Marquee) >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    if ($matching_game_node.screen.count -lt 1)
    {
        $boxart = $null;
        foreach ($img in $imgsArrJSON)
        {
            if ($img.type -eq "boxart" -and $img.side -eq "front")
            {
                $boxart=$img;
                break;
            }
        }


        if ($boxart -ne $null)
        {
            $BoxArtURL = $baseImgURL+$boxart.filename;
            $extension = [System.IO.Path]::GetExtension($BoxArtURL);
    
            $ImageFname = $path + $extension;
            $TargetFile = $global:imageDir + "cover\"+ $ImageFname;

            $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
            if ($retVal -ne $true)
            {
                #If here Download The Game List File
                Write-Host "SOURCE"
                Write-Host -foregroundcolor cyan -backgroundcolor black $BoxArtURL
                Write-Host "TARGET"
                Write-Host -foregroundcolor cyan -backgroundcolor black $TargetFile
                $webclient = new-object System.Net.WebClient
                $webclient.DownloadFile($BoxArtURL, $TargetFile)
            }
        }#end of if ($clearLogo -ne $null)
    }


    return;
}




# ****************************************************************************************************************************
# Make ASCII Str
# ****************************************************************************************************************************
function makeASCIIStr([string] $in_str)
{
    $enc = [system.Text.Encoding]::ASCII
    $asciiDescBytes = $enc.GetBytes($in_str)
    $asciiDescStr = $enc.GetString($asciiDescBytes)

    if ($in_str -ne $asciiDescStr)
    {
        $asciiDescStr=$asciiDescStr.replace("?", "");#Strip All ?
        Write-Host "STRIPPING NON ASCII CHARS" -foregroundcolor red
        Write-Host $asciiDescStr -foregroundcolor red
    }

    return $asciiDescStr;
}



#*****************************************************************************************************************************************
#GetGamesDBCommonTables
#Loads $Global:APIGenres
#Loads $global:ht_APIDevelopers
#Loads $global:ht_APIPublishers
#*****************************************************************************************************************************************
function GetGamesDBCommonTables()
{
    #GET SHARED GENRES >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $url = $global:GamesDbBaseUrl + "Genres?apikey=" + $global:GamesDb_APIKey;

    $TargetFile = $global:Path2DownloadDir + "Genres.json";
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        #Only Download if NOT already there
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }

    #Now Open Platforms.xml
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }


    $global:ht_APIGenres = @{} #Convert to HashTable
    $json.data.genres.psobject.properties | Foreach { $global:ht_APIGenres[$_.Name] = $_.Value }


    #GET SHARED DEVELOPERS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $url = $global:GamesDbBaseUrl + "Developers?apikey=" + $global:GamesDb_APIKey;

    $TargetFile = $global:Path2DownloadDir + "Developers.json";
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        #Only Download if NOT already there
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }

    #Now Open json
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }


    $global:ht_APIDevelopers = @{} #Convert to HashTable
    $json.data.developers.psobject.properties | Foreach { $global:ht_APIDevelopers[$_.Name] = $_.Value }
    

    #GET SHARED PUBLISHERS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $url = $global:GamesDbBaseUrl + "Publishers?apikey=" + $global:GamesDb_APIKey;

    $TargetFile = $global:Path2DownloadDir + "Publishers.json";
    Write-Host -foregroundcolor black -backgroundcolor yellow $TargetFile

    $retVal = Test-Path -LiteralPath  $TargetFile -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        #Only Download if NOT already there
        Write-Host -foregroundcolor cyan -backgroundcolor black $url
        $webclient = new-object System.Net.WebClient
        $webclient.DownloadFile($url, $TargetFile)
    }

    #Now Open json
    $json = $null
    $json = Get-Content -LiteralPath $TargetFile | ConvertFrom-Json
    if ($json -eq $null)
    {
        HandleError "Unable to open results json file $TargetFile as json"
    }


    $global:ht_APIPublishers = @{} #Convert to HashTable
    $json.data.publishers.psobject.properties | Foreach { $global:ht_APIPublishers[$_.Name] = $_.Value }



}


#*****************************************************************************************************************************************
#Iterate Mapping game List.
# Prompt user to select a match or skip. Call GetGame() with selected ID to Download by Game ID, then Insert that Info into theGamesdbMapping.xml
#In the title of the displayed GridView I will display Source Name, Click cancel to skip, or select row and OK to get Download Game Info and use meta data, etc.
#*****************************************************************************************************************************************
function getGameIDs()
{
    $gamesListsPath = "$global:Path2DownloadDir" + $global:PlatformStr + "\ByGameName\"
    Write-Host -foregroundcolor green -backgroundcolor black "getGameIDs() $gamesListsPath"

    #Open Path2GamesMappingXML
    [xml] $xwm = $null
    $xwm = Get-Content $global:Path2GamesMappingXML
    if ($xwm -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }

    #iterate each gamslist mapping game Node
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    Foreach($gn in $xwm.gameList.game)
    {
        [System.Xml.XmlNode] $needsNode = $gn.SelectSingleNode("needs");

        if ($needsNode -eq $null)
        {
            continue;#Nothing to Process
        }

        #Do we have gameID yet?
        $id = $gn.id;
        if ($id.length -gt 0)
        {
            continue;#We have already attempted to get an ID.
        }

        #If here we need the GameID
        $path =  $gn.path
        $name =  $gn.game_title

        if ($name.Length -eq 0)
        {
            $name=$path;
        }

        $ByGameNameJSON = $gamesListsPath + $path + ".json";
        if (!(Test-Path -LiteralPath $ByGameNameJSON))
        {
            APIGetGameList $name $path #Download ByGameName json File, unless it already exists.
        }

        if (!(Test-Path -LiteralPath $ByGameNameJSON))
        {
           HandleError("$ByGameNameJSON does not exist") #If still not here signal problem!
        }

        Write-Host "Creating Game ID Match For"
        Write-Host -foregroundcolor cyan -backgroundcolor black $path

        #id Node
        [System.Xml.XmlNode] $IDNode = $gn.SelectSingleNode("id");
        if ($IDNode -eq $null)
        {
            $IDNode = $gn.OwnerDocument.CreateElement("id")
            $gn.AppendChild($IDNode);
        }


        #Open json Game List File
        $json = $null
        $json = Get-Content -LiteralPath $ByGameNameJSON | ConvertFrom-Json
        if ($json -eq $null)
        {
            HandleError "Unable to open results json file $FullName as json"
        }

        if ($json.data.games.length -eq 0)
        {
            Write-Host -foregroundcolor red -backgroundcolor black "0 possible matches returned from games db! Setting game ID to -1"
            #If we are here there is NOTHING to choose from!
            $IDNode.InnerText="-1";#-1 Means no selections to choose from at Games DB
            $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
            $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
            $xwm.Save($sw);
            $sw.Close();
            continue;
        }

        #Never Auto Select even if it only comes back with one match. Sometimes what it comes back with is crap!
        #Prompt with Grid View for user to make a selection
        $game = $null;
        $titleStr = "select match for " + $path + " or cancel to skip (no match)"
        $game = $json.data.games | Out-GridView -OutputMode Single -Title $titleStr


        if ($game -ne $null)
        {
            #If here a selection was made!
            Write-Host -foregroundcolor cyan -backgroundcolor black "You selected $gameIDStr"

            $IDNode.InnerText= $game.id;
            

            #game_title Node
            [System.Xml.XmlNode] $GameTitleNode = $gn.SelectSingleNode("game_title");
            if ($GameTitleNode -eq $null)
            {
                $GameTitleNode = $gn.OwnerDocument.CreateElement("game_title")
                $gn.AppendChild($GameTitleNode);
            }
            $GameTitleNode.InnerText= $game.game_title;



            #release_date node
            [System.Xml.XmlNode] $rdNode = $gn.SelectSingleNode("release_date");
            if ($rdNode -eq $null)
            {
                $rdNode = $gn.OwnerDocument.CreateElement("release_date")
                $gn.AppendChild($rdNode);
            }
            $rdNode.InnerText= $game.release_date;

        }
        else
        {
            Write-Host -foregroundcolor red -backgroundcolor black "Cancelled. No valid match returned from games db! Setting game ID to -2"
            #If here skipped no match, move games list xml file to skippedGamesListsFolder
            $IDNode.InnerText= -2;#-2 Means Cancelled by User

        }

        #Save Mapping XML with User Selections for Game ID's
        $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
        $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
        $xwm.Save($sw);
        $sw.Close();

    }#end of Foreach($gameNode in $xg.gameList.game)

   Write-Host -foregroundcolor green -backgroundcolor black "Leaving getGameIDs()"
}

#*****************************************************************************************************************************************
#Iterate gamesDBMapping List Files. 
#*****************************************************************************************************************************************
function GetMetaData()
{
Write-Host -foregroundcolor green -backgroundcolor black "GetMetaData() for $global:PlatformStr"

GetGamesDBCommonTables #Genres, Developers, Publishers

    [xml] $xr = $null
    $xr = Get-Content $global:Path2GamesMappingXML
    if ($xr -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }


    #iterate each game Node
    Foreach($gameNode in $xr.gameList.game)
    {
        [System.Xml.XmlNode] $needsNode = $gameNode.SelectSingleNode("needs");
        if ($needsNode -eq $null)
        {
            continue;#nothing needed
        }

        [System.Xml.XmlNode] $metadataNode = $needsNode.SelectSingleNode("metadata");
        if ($metadataNode -eq $null)
        {
            continue;#No metadata needed
        }

        #If here we need metadata

        [int] $id = $gameNode.id;
        if ($id -gt 0)#Without a game ID nothing we can do
        {
            API_GetGameByGameID $gameNode
        }
    }


    Write-Host -foregroundcolor green -backgroundcolor black "Leaving GetMetaData()"
}

#*****************************************************************************************************************************************
#Iterate gamesDBMapping List Files. 
#*****************************************************************************************************************************************
function GetImages()
{
Write-Host -foregroundcolor green -backgroundcolor black "GetImages() for $global:PlatformStr"

    [xml] $xr = $null
    $xr = Get-Content $global:Path2GamesMappingXML
    if ($xr -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }


    #iterate each game Node
    Foreach($gameNode in $xr.gameList.game)
    {
        [System.Xml.XmlNode] $needsNode = $gameNode.SelectSingleNode("needs");
        if ($needsNode -eq $null)
        {
            continue;#nothing needed
        }

        [System.Xml.XmlNode] $mediaNode = $needsNode.SelectSingleNode("media");
        if ($mediaNode -eq $null)
        {
            continue;#No metadata needed
        }


        [int] $id = $gameNode.id;
        if ($id -gt 0)
        {
            API_GetGameImages $gameNode
        }
    }


    Write-Host -foregroundcolor green -backgroundcolor black "Leaving GetMetaData()"
}


#*****************************************************************************************************************************************
#Main Execution Begins Here
#*****************************************************************************************************************************************
Clear-Host

InitReg
AksUserPlatform #Must be called once, then can be commented out until you want to change platform.
InitDirs #Create Base Dirs, needs PlatformStr set 1st.

AskUserGamesListXML #Must be called once, then can be commented out until you want to change platform.

gamesDBMapping_Maintenance #Should always be called. Add/Remove Nodes corresponding to gameslist.xml, into mapping.

#Step 2 coment out step 1
getGameIDs #Thru User Interaction get GameID's into theGamesdbMapping.xml


#Step 3 coment out step 1 and 2

GetMetaData
GetImages



 
