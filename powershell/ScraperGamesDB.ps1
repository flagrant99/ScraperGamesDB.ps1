#*****************************************************************************************************************************************
#This is the PowerShell Script For Scraping Metadata from Gamesdb.net
#And putting into EmulationStation gameslist.xml
#
#gamesdb Links
#https://thegamesdb.net/
#https://api.thegamesdb.net/#/
#
#v2019-11-09
#*****************************************************************************************************************************************



#*****************************************************************************************************************************************
#TO USE: set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************
#Local Paths
$global:Path2DownloadDir = "E:\Downloads\thegamesdb\"
$global:RegKeyStr = "HKCU:\SOFTWARE\retroPS_ScraperGamesDB"
$global:Path2RomsDir = "D:\_GAMES\RetroPI\roms\";

#gamesDBConfigs
#$global:GamesDb_APIKey= "XXX"; # (PUBLIC KEY)
$global:GamesDb_APIKey= "XXX"; # (PRIVATE KEY)
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


# ****************************************************************************************************************************
# HANDLE ERROR
# ****************************************************************************************************************************
function HandleError([string] $ErrMsg)
{
    Write-Host -foregroundcolor red -backgroundcolor black $ErrMsg
    Exit #Stop Execution of the script
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
function InitDirs($platform)
{
    Write-Host -foregroundcolor green -backgroundcolor black "InitDirs() $platform"

    $TargetDir = "$global:Path2DownloadDir" + "$platform\"
    $retVal = Test-Path -LiteralPath  $TargetDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $TargetDir #Create the Dir
    }

    $global:Path2GamesMappingXML = $TargetDir + "gamesDBMapping.xml";
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

    #Download All Images here
    $global:imageDir = $TargetDir + "m\"
    $retVal = Test-Path -LiteralPath  $global:imageDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $imageDir #Create the Dir
    }

    #Download All Images here
    $marqueeDir = $global:imageDir + "marquee\";
    $retVal = Test-Path -LiteralPath  $marqueeDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $marqueeDir #Create the Dir
    }

    #Download All Images here
    $coverDir = $global:imageDir + "cover\";
    $retVal = Test-Path -LiteralPath  $coverDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $coverDir #Create the Dir
    }


    Set-Location -Path $TargetDir #Change Dir to Root of Platform

    Write-Host -foregroundcolor green -backgroundcolor black "Scraper Starting downloading to:"
    Write-Host -foregroundcolor green -backgroundcolor black $TargetDir
    Write-Host


return;
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
#http://thegamesdb.net/api/GetPlatformsList.php
#Let user pick Platform so we can get Platform #
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

    $TargetDir = "$global:Path2DownloadDir" + "$global:PlatformStr\" + "ByGameName\"

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
#Pass a GameNode from  gamesDBMapping.xml
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
    [string] $genre_KeyStr = $jsonGame.genres[0];
    [string] $json_genreStr= $global:ht_APIGenres[$genre_KeyStr].name;

    $json_releaseDate = $null;
    $json_releaseDate = $jsonGame.release_date;
    if ($json_releaseDate -ne $null)
    {
        [DateTime] $dt = [DateTime] $json_releaseDate;
        $json_releaseDate = $dt.ToString("yyyyMMddT000000")
    }

    [string] $json_players = "";
    if ($jsonGame.players -ne $null)
    {
        [string] $json_players = $jsonGame.players;
    }



    [string] $publisher_KeyStr = $jsonGame.publishers[0];
    [string] $json_publisherStr= $global:ht_APIPublishers[$publisher_KeyStr].name;
    $json_publisherStr = makeASCIIStr $json_publisherStr;

    [string] $devloper_KeyStr = $jsonGame.developers[0];
    [string] $json_developerStr= $global:ht_APIDevelopers[$devloper_KeyStr].name;
    $json_developerStr = makeASCIIStr $json_developerStr;


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

    [xml] $xg = $null
    $xg = Get-Content $global:Path2GamesListXML
    if ($xg -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    $matching_game_node = $null;
    Foreach($gameNode in $xg.gameList.game)
    {
        #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
        $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path)
        if ($pathStr -eq $path)
        {
            $matching_game_node = $gameNode;
        }
    }#end of Foreach($gameNode in $xg.gameList.game)

    if ($matching_game_node -eq $null)
    {
        HandleError "Unable to find matching game node in games.xml"
    }

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
        $node = $xg.CreateElement("desc")
        $matching_game_node.AppendChild($node);
    }

    if ($matching_game_node.desc.length -eq 0)
    {
        $matching_game_node.desc = $json_asciiDescStr;
    }


    #genre Node
    if ($matching_game_node.genre.count -lt 1)
    {#Only Add if not there
        Write-Host -foregroundcolor red -backgroundcolor black "genreStr: $genreStr"
        $node = $xg.CreateElement("genre")
        
        $matching_game_node.AppendChild($node);
    }

    if ($matching_game_node.genre.length -eq 0)
    {
        $matching_game_node.genre = $json_genreStr;
    }
    

    #releasedate
    if ($matching_game_node.releasedate.count -lt 1)
    {#Only Add if not there
        $node = $xg.CreateElement("releasedate")
        $matching_game_node.AppendChild($node);
    }

    if ($matching_game_node.releasedate.length -eq 0)
    {
        $matching_game_node.releasedate = $json_releaseDate;
    }


    #players
    if ($matching_game_node.players.count -lt 1)
    {#Only Add if not there
        if ($json_players.length -gt 0)
        {
            $node = $xg.CreateElement("players")
            $matching_game_node.AppendChild($node);
        }
    }

    if ($matching_game_node.players.length -eq 0 -and $json_players.length -gt 0)
    {
        $matching_game_node.players = $json_players;
    }



    #publisher

    if ($matching_game_node.publisher.count -lt 1)
    {#Only Add if not there
        $node = $xg.CreateElement("publisher")
        $matching_game_node.AppendChild($node);
    }

    $matching_game_node.publisher = $json_publisherStr;

    #developer


    if ($matching_game_node.developer.count -lt 1)
    {#Only Add if not there
        $node = $xg.CreateElement("developer")
        $matching_game_node.AppendChild($node);
    }

    $matching_game_node.developer = $json_developerStr;


    #Write a GameNode in Games.xml Format In this Dir as If we were going to copy and paste it, so we can view on it's own.
    saveLocalGamesXML $TargetGameDir $matching_game_node

    $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
    $sw = New-Object System.IO.StreamWriter($global:Path2GamesListXML, $false, $utf8)#2nd arg indicates append
    $xg.Save($sw);
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
#Pass a GameNode from  gamesDBMapping.xml
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
    #First Make a backup copy from BEFORE our EDITS and put in game dir. This way we can always ROLLBACK if something goes wrong.
    Copy-Item -LiteralPath $global:Path2GamesListXML -Destination $TargetGameDir

    [xml] $xg = $null
    $xg = Get-Content $global:Path2GamesListXML
    if ($xg -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    $matching_game_node = $null;
    Foreach($gameNode in $xg.gameList.game)
    {
        #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
        $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path)
        if ($pathStr -eq $path)
        {
            $matching_game_node = $gameNode;
        }
    }#end of Foreach($gameNode in $xg.gameList.game)

    if ($matching_game_node -eq $null)
    {
        HandleError "Unable to find matching game node in games.xml"
    }

    #If we are here we have the game node to edit


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #IMAGE PROCESSING 
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



#http://thegamesdb.net/banners/clearlogo/328.png

# ****************************************************************************************************************************
#Scans Emulation Station GamesList.xml for GameNodes that Have Missing Marquee.
#Using name it calls ByGameName() to get Possible Game List Match Files from GamesDB.NET
#The Game List Possible Match json Files are Stored under Downlooads\thegamesdb\PlatFormName\ByGameID and ONLY downloaded if they don't already exist.
# ****************************************************************************************************************************
function ScanGamesList_XML()
{
    Write-Host -foregroundcolor green -backgroundcolor black "ScanGamesList_XML()"
    Write-Host -foregroundcolor green -backgroundcolor black "Looking for GameNodes that Have Missing Genre. Using name it calls APIGetGameList() to get Possible Game List Match Files."
    Write-Host

    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    $missingGamesPaths=0
    $missingVids=0
    $missingImgs=0

    Write-Host -foregroundcolor green -backgroundcolor black $xw.gameList.game.Count " games in gamelist.xml"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        if ($gameNode.desc.count -ne 1)
        {
            "Marquee Missing"
            $gameNode
            $gameName = $gameNode.name;
            $pathStr = [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path); ; #Save the File with Path Name not game Name, Game Name can change. Path for Rom Name cannot and is the key we use to match back to game node in games.xml
            APIGetGameList $gameName $pathStr
        }


    }#end of Foreach($gameNode in $xw.gameList.game)

    
    Write-Host -foregroundcolor green -backgroundcolor black "Missing Files Pointed to by GamePaths Count:" $missingGamesPaths
    Write-Host -foregroundcolor green -backgroundcolor black "Missing Video Node Count:" $missingVids
    Write-Host -foregroundcolor green -backgroundcolor black "Missing Image Node Count:" $missingImgs

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving ScanGamesList_XML"
    Write-Host
}

#*****************************************************************************************************************************************
#Iterate Game List Files. Prompt user to select a match or skip. Call GetGame() with selected ID to Download by Game ID, then Insert that Info into gamesDBMapping.xml
#In the title of the displayed GridView I will display Source Name, Click cancel to skip, or select row and OK to get Download Game Info and use meta data, etc.
#*****************************************************************************************************************************************
function gamesDBMapping($PlatformStr)
{
    Write-Host -foregroundcolor green -backgroundcolor black "gamesDBMapping()"


    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesMappingXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open Path2GamesMappingXML xml file $global:Path2GamesMappingXML as xml"
    }
    [System.Xml.XmlElement] $gameListNode = $xw.DocumentElement;


    $gamesListsPath = "$global:Path2DownloadDir" + $PlatformStr + "\ByGameName\"

    $FilesArr = get-childitem -Recurse -Path $gamesListsPath -include *.json
    Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " Games Lists xmls"


    #Iterate Each json file in $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName

        Write-Host "Finding Match For"
        Write-Host -foregroundcolor cyan -backgroundcolor black $fileTitle

        if (!(Test-Path -LiteralPath $FullName))
            {
                HandleError("$FullName does not exist") #If this happens signal problem!
                exit
            }

        #Did we already set a matching GameID for this?
        $matching_game_node = $null;
        Foreach($gameNode in $xw.gameList.game)
        {
            #Strip off extension to get pathTitle, Game Name is not reliable. It can change. path without extension will not
            $pathStr =  [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path)
            if ($pathStr -eq $fileTitle)
            {
                $matching_game_node = $gameNode;
            }
        }#end of Foreach($gameNode in $xg.gameList.game)

        if ($matching_game_node -eq $null)
        {
            Write-Host "Creating Match Node"
            [System.Xml.XmlElement] $game_node = $xw.CreateElement("game")
            $gameListNode.AppendChild($game_node);

            #path Node
            $node = $xw.CreateElement("path")
            $node.InnerText = $fileTitle;
            $game_node.AppendChild($node);

            #game_title Node
            $node = $xw.CreateElement("game_title")
            $game_node.AppendChild($node);

            #game_title Node
            $node = $xw.CreateElement("id")
            $game_node.AppendChild($node);

            $node = $xw.CreateElement("release_date")
            $game_node.AppendChild($node);


            $matching_game_node=$game_node;
        }#end of if ($matching_game_node -eq $null)

        if ($matching_game_node.id.Length -eq 0) #This means selection was never made!
        {
            Write-Host "Creating Match"
            #Open json Game List File
            $json = $null
            $json = Get-Content -LiteralPath $FullName | ConvertFrom-Json
            if ($json -eq $null)
            {
                HandleError "Unable to open results json file $FullName as json"
            }

            if ($json.data.games.length -eq 0)
            {
                $matching_game_node.id="-1";#-1 Means no selection from Games DB
                #Save Mapping XML with User Selections for Game ID's
                $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
                $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
                $xw.Save($sw);
                $sw.Close();
                continue;
            }

            if ($json.data.games.length -eq 1)#Auto Select
            {
                $game = $json.data.games[0];
            }
            else
            {
                #Prompt with Grid View for user to make a selection
                $game = $null;
                $titleStr = "select match for " + $fileTitle + " or cancel to skip (no match)"
                $game = $json.data.games | Out-GridView -OutputMode Single -Title $titleStr
            }


            if ($game -ne $null)
            {
                #If here a selection was made!
                $gameIDStr = $game.id;
                $gameTitle = $game.game_title;

                $matching_game_node.game_title=$gameTitle;
                $matching_game_node.id="$gameIDStr";
                $matching_game_node.release_date=$game.release_date;

                #Save Mapping XML with User Selections for Game ID's
                $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
                $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
                $xw.Save($sw);
                $sw.Close();

                Write-Host -foregroundcolor cyan -backgroundcolor black "You selected $gameIDStr"
            }
            else
            {
                Write-Host "No Match Found"
                #If here skipped no match, move games list xml file to skippedGamesListsFolder
                $matching_game_node.id="-2";#-1 Means no selection made or skipped

                #Save Mapping XML with User Selections for Game ID's
                $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
                $sw = New-Object System.IO.StreamWriter($global:Path2GamesMappingXML, $false, $utf8)#2nd arg indicates append
                $xw.Save($sw);
                $sw.Close();

                Write-Host -foregroundcolor cyan -backgroundcolor black "No Selection Made, Skipping Selection List File"
            }
            
        }#end of if ($matching_game_node.id.Length -eq 0)


    }#END OF iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



   Write-Host -foregroundcolor green -backgroundcolor black "Leaving gamesDBMapping"
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
        [int] $id = $gameNode.id;
        if ($id -gt 0)
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
        [int] $id = $gameNode.id;
        if ($id -gt 0)
        {
            API_GetGameImages $gameNode
        }
    }


    Write-Host -foregroundcolor green -backgroundcolor black "Leaving GetMetaData()"
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
#Main Execution Begins Here
#*****************************************************************************************************************************************
Clear-Host

InitReg
AksUserPlatform
InitDirs $global:PlatformStr #Create Base Dirs, needs PlatformStr set 1st.


AskUserGamesListXML




#Step 1 Run ScanGamesList_XML with everything else commented out to create all game lists files, for reach game that we need to determine GameID
ScanGamesList_XML

#Step 2 coment out step 1
gamesDBMapping $global:PlatformStr #Thru User Interaction get GameID's into gamesDBMapping.xml


#Step 3 coment out step 1 and 2

GetMetaData
GetImages



 
