#*****************************************************************************************************************************************
#This is the PowerShell Script For Reporting on gamelist.xml for RetroPie
#Reports ON:
#Duplicate Nodes
#Missing Files
#Missing Videos
#Unused Images
#
#v2019-11-11
#*****************************************************************************************************************************************


#*****************************************************************************************************************************************
#To Use set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************

$global:RegKeyStr = "HKCU:\SOFTWARE\retroPS_GLR"
$global:Path2RomsDir = "D:\_GAMES\RetroPI\roms\";
$global:Path2GamesListXML = "D:\_GAMES\RetroPI\roms\XXX\gamelist.xml"

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
    clear-host
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
#Ask User Games List XML
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
# Create Reg Keys to store some settings
# ****************************************************************************************************************************
function InitReg()
{
    Write-Host -foregroundcolor green -backgroundcolor black "InitReg()"
    $retVal = Test-Path -Path $global:RegKeyStr

    

     if ($retVal -eq $false)
     {
         New-Item -Path $global:RegKeyStr
         New-ItemProperty -Path $global:RegKeyStr -Name "Path2GamesListXML" -Value ""
     }
     else
     {
        $global:Path2GamesListXML = Get-ItemPropertyValue -Path $global:RegKeyStr -Name "Path2GamesListXML"
     }
}

# ****************************************************************************************************************************
# ERROR.
# My Fixer sometimes inserted image and video nodes twice inside the same game element. Just exit if we encounter duplicate nodes inside the same game element. 
# This will be considered an error.
# ****************************************************************************************************************************
function ScanGamesList4DuplicateNodes()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "ScanGamesList4DuplicateNodes()"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {

        if ($gameNode.video.count -gt 1)
        {
            $gameNode
            HandleError "Extra Video Node Detected Exiting"
        }

        if ($gameNode.marquee.count -gt 1)
        {
            $gameNode
            HandleError "Extra marquee Node Detected Exiting"
        }

        if ($gameNode.image.count -gt 1)
        {
            $gameNode
            HandleError "Extra Image Node Detected Exiting"
        }


        if ($gameNode.path.count -ne 1)
        {
            $gameNode
            HandleError "path.count -ne 1 Exiting"
        }

        if ($gameNode.name.count -ne 1)
        {
            $gameNode
            HandleError "name.count -ne 1 Exiting"
        }

        if ($gameNode.desc.count -gt 1)
        {
            $gameNode
            HandleError "Extra desc Node Detected Exiting"
        }

        if ($gameNode.rating.count -gt 1)
        {
            $gameNode
            HandleError "Extra rating Node Detected Exiting"
        }

        if ($gameNode.releasedate.count -gt 1)
        {
            $gameNode
            HandleError "Extra releasedate Node Detected Exiting"
        }

        if ($gameNode.publisher.count -gt 1)
        {
            $gameNode
            HandleError "Extra publisher Node Detected Exiting"
        }

        if ($gameNode.genre.count -gt 1)
        {
            $gameNode
            HandleError "Extra genre Node Detected Exiting"
        }
        
        if ($gameNode.players.count -gt 1)
        {
            $gameNode
            HandleError "Extra players Node Detected Exiting"
        }        

        if ($gameNode.developer.count -gt 1)
        {
            $gameNode
            HandleError "Extra developer Node Detected Exiting"
        }        

    }#end of Foreach($gameNode in $xw.gameList.game)

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving ScanGamesList4DuplicateNodes() No Duplicates Detected..."
}


# ****************************************************************************************************************************
# ERROR.
# Verify Path, video, and marquee, image exist for each game node.
# ****************************************************************************************************************************
function ScanGamesList4MissingFiles()
{
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
    $missingMarquee=0

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "ScanGamesList4MissingFiles()"

    $htVidhKeys = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $gameName = $gameNode.Name
        $genre = $gameNode.genre

        $retVal = Test-Path -LiteralPath  $gamePath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
        if ($retVal -eq $false)
        {
            Write-Host "gamepath missing $gamePath" -foregroundcolor red
            $missingGamesPaths++
        }


        if ($genre.length -gt 0)
        {
            $genre = $genre.ToLower();
            if ($genre.Contains("bios") -eq $true)
            {
                continue;#Skip over bios genre.
            }

        }


        $videoPath = $gameNode.video
        if ($videoPath.length -gt 0)
        {
            $retVal = Test-Path -LiteralPath  $videoPath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
            if ($retVal -eq $false)
            {
                Write-Host "Video file missing $videoPath" -foregroundcolor red
                $missingVids++;
            }
        }

        $imagePath = $gameNode.image
        if ($imagePath.length -gt 0)
        {
            $retVal = Test-Path -LiteralPath  $imagePath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
            if ($retVal -eq $false)
            {
                Write-Host "Image file missing $imagePath" -foregroundcolor red
                $missingImgs++
            }
        }

        $marqueePath = $gameNode.marquee
        if ($marqueePath.length -gt 0)
        {
            $retVal = Test-Path -LiteralPath  $marqueePath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
            if ($retVal -eq $false)
            {
                Write-Host "marquee file missing $marqueePath" -foregroundcolor red
                $missingMarquee++
            }
        }


    }#end of Foreach($gameNode in $xw.gameList.game)

    if ($missingGamesPaths -gt 0)
    {
         HandleError "Missing Files Pointed to by GamePaths Count:" $missingGamesPaths
    }

    if ($missingVids -gt 0)
    {
         HandleError "Missing Video Paths Count:" $missingVids
    }

    if ($missingImgs -gt 0)
    {
         HandleError "Missing Image Paths Count:" $missingImgs
    }

    if ($missingMarquee -gt 0)
    {
         HandleError "Missing marquee Paths Count:" $missingMarquee
    }

    
    
    Write-Host -foregroundcolor green -backgroundcolor black "Leaving ScanGamesList4MissingFiles() All Files exist...."
}

# ****************************************************************************************************************************
# ERROR
# Scan for Roms missing in Games List
# ****************************************************************************************************************************
function ScanForRomsMissingInGamesList()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "ScanForRomsMissingInGamesList()  - These ROMS exist but do NOT have game nodes!"
    $romsCtr =0
    #Create $htPathKeys so we have a hashTable with relative game path in Keys
    $htPathKeys = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($gamePath)
        if (!$htPathKeys.ContainsKey($gamePath))
        {
            $htPathKeys.Add($gamePath, $fileTitle);
        }
    }


   #Now lets get list of zip files in Console Dir
   $FilesArr = get-childitem -Recurse -Path $global:ConsoleDir -include *.zip

    #Iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName
        $PartialName = $FullName.Substring($global:ConsoleDir.Length)
        $PartialName = $PartialName.Replace('\', '/')
        $RelativeName = ".$PartialName"

        if (!$htPathKeys.ContainsKey($RelativeName))
        {
            $romsCtr++
            Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
    }#end of foreach($file in $FilesArr)


    if ($romsCtr -gt 0)
    {
        HandleError "Roms Missing from games list:" $romsCtr
    }

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving ScanForRomsMissingInGamesList(). All Games exist in xml...."
}


# ****************************************************************************************************************************
# I have seen Videos that exist are not being linked to. ORPHANED VIDEOS
# ****************************************************************************************************************************
function Scan4OrphanedVideos()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "Scan4OrphanedVideos() - AKA Orphaned, Unused"

    #Create $htVideoKeys so we have a hashTable with relative video path in Keys, I am putting Path to Zip in value in case we need to use it as key later.
    $htVideoKeys = @{}

    $missingVidsCnt=0

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $videoPath = ""
        $videoPath = $gameNode.video
        if ($videoPath.length -lt 1)
        {
            continue;
        }

        if (!(Test-Path -LiteralPath $videoPath))
        {
            HandleError("$videoPath does not exist") #If this happens signal problem!
            exit
        }

        if (!$htVideoKeys.ContainsKey($videoPath))
        {
            $htVideoKeys.Add($videoPath, $gamePath);
        }
    }#end of Foreach($gameNode in $xw.gameList.game)

    Write-Host -foregroundcolor green -backgroundcolor black $htVideoKeys.Keys.Count " Video Nodes"
   
    

   #Now lets get list of Video files in Image Dir
   $FilesArr = get-childitem -Recurse -Path $global:ImagePath -include *.mp4
   Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " mp4's"

    #Iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName
        $PartialName = $FullName.Substring($global:ConsoleDir.Length)
        $PartialName = $PartialName.Replace('\', '/')
        $RelativeName = ".$PartialName"

        if (!$htVideoKeys.ContainsKey($RelativeName))
        {   #In here if the gameslist.xml does not have our video but it exists!
            $missingVidsCnt++
            Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)

    
    if ($missingVidsCnt -gt 0)
    {
        Write-Host -foregroundcolor red -backgroundcolor black "Orphaned Unused Videos:" $missingVidsCnt
    }
    Write-Host -foregroundcolor green -backgroundcolor black "Leaving Scan4OrphanedVideos()"
}


# ****************************************************************************************************************************
# I have seen Images that exist are not being linked to. Orphaned, Unused
# ****************************************************************************************************************************
function Scan4OrphanedImages()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "Scan4OrphanedImages() - Orphaned, Unused"

    $orphanedImgs=0

    #Create $htImageKeys so we have a hashTable with relative Image path in Keys, I am putting Path to Zip in value in case we need to use it as key later.
    $htImageKeys = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $imagePath = ""
        $imagePath = $gameNode.image
        $marquee = $gameNode.marquee

        if ($gamePath -eq "./airwolf.zip")
        {
            $t = ""
        }

        if ($imagePath.length -gt 1)
        {
            if (!(Test-Path -LiteralPath $imagePath))
            {
                HandleError("$imagePath does not exist") #If this happens signal problem!
                exit
            }

            if (!$htImageKeys.ContainsKey($imagePath))
            {
                $htImageKeys.Add($imagePath, $gamePath);
            }
        }

        if ($marquee.length -gt 1)
        {
            if (!(Test-Path -LiteralPath $marquee))
            {
                HandleError("$marquee does not exist") #If this happens signal problem!
                exit
            }

            if (!$htImageKeys.ContainsKey($marquee))
            {
                $htImageKeys.Add($marquee, $gamePath);
            }
        }


    }#end of Foreach($gameNode in $xw.gameList.game) 

    Write-Host -foregroundcolor green -backgroundcolor black $htImageKeys.Keys.Count " Image Nodes"
   

   #Now lets get list of Image files in Image Dir
   $FilesArr = get-childitem -Recurse -Path $global:ImagePath -include *.jpg,*.png
   Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " jpg's and pngs"

    #Iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
        $FullName = $file.FullName
        $PartialName = $FullName.Substring($global:ConsoleDir.Length)
        $PartialName = $PartialName.Replace('\', '/')
        $RelativeName = ".$PartialName"

        if (!$htImageKeys.ContainsKey($RelativeName))
        {   #In here if the gameslist.xml does not have our video but it exists!
            #We need to find our game node and add a video child

            $parentDirTitle = [System.IO.Path]::GetFileNameWithoutExtension($file.Directory);
            if ($parentDirTitle -eq "wheel")#Ignore if Parent Dir is wheel I am using those for attractmode
            {
                continue;
            }

            if ($parentDirTitle -eq "mixart")#ignore mixart might use later.
            {
                continue;
            }
            
            
            $orphanedImgs++
            Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)

    if ($orphanedImgs -gt 0)
    {
        Write-Host -foregroundcolor red -backgroundcolor black "Orphaned Images " $orphanedImgs
    }

}



# ****************************************************************************************************************************
# WARNING
# Report on counts of missing nodes by type from gameslist.xml
#
# I want a bunch of report files written to r dir
#
# ****************************************************************************************************************************
function ReportMissingNodeCounts()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host 
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "ReportMissingNodeCounts()"
    Write-Host -foregroundcolor green -backgroundcolor black $xw.gameList.game.Count " games in gameslist"

    #HashTables
    $ht_perfect = @{};

    $ht_genre = @{};
    $ht_desc = @{};
    $ht_publisher = @{};
    $ht_developer = @{};
    $ht_releasedate = @{};
    $ht_players = @{};

    $ht_video = @{};
    $ht_marquee = @{};
    $ht_image = @{};
    

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $perfect="Y";
        #genre
        if ($gameNode.genre.count -lt 1)
        {
            $perfect="N";
            if ($ht_genre.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_genre.Add($gameNode.path, $gameNode.name);
            }
        }

        #desc
        if ($gameNode.desc.count -lt 1)
        {
            $perfect="N";
            if ($ht_desc.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_desc.Add($gameNode.path, $gameNode.name);
            }
        }

        #publisher
        if ($gameNode.publisher.count -lt 1)
        {
            $perfect="N";
            if ($ht_publisher.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_publisher.Add($gameNode.path, $gameNode.name);
            }
        }

        #developer
        if ($gameNode.developer.count -lt 1)
        {
            $perfect="N";
            if ($ht_developer.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_developer.Add($gameNode.path, $gameNode.name);
            }
        }

        #releasedate
        if ($gameNode.releasedate.count -lt 1)
        {
            $perfect="N";
            if ($ht_releasedate.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_releasedate.Add($gameNode.path, $gameNode.name);
            }
        }

        #players
        if ($gameNode.players.count -lt 1)
        {
            $perfect="N";
            if ($ht_players.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_players.Add($gameNode.path, $gameNode.name);
            }
        }

        #video
        if ($gameNode.video.count -lt 1)
        {
            $perfect="N";
            if ($ht_video.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_video.Add($gameNode.path, $gameNode.name);
            }
        }

        #marquee
        if ($gameNode.marquee.count -lt 1)
        {   
            $perfect="N";
            if ($ht_marquee.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_marquee.Add($gameNode.path, $gameNode.name);
            }
        }

        #image        
        if ($gameNode.image.count -lt 1)
        {
            $perfect="N";
            if ($ht_image.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_image.Add($gameNode.path, $gameNode.name);
            }
        }


        if ($perfect -eq "Y")
        {
            if ($ht_perfect.ContainsKey($gameNode.path) -eq $false)
            {
                $ht_perfect.Add($gameNode.path, $gameNode.name);
            }
        }

    }#end of Foreach($gameNode in $xw.gameList.game)


    #Sorts Alpha
    WriteReport $ht_genre "needs_genre.txt" "N";
    WriteReport $ht_desc "needs_desc.txt" "N";
    WriteReport $ht_publisher "needs_publisher.txt" "N";
    WriteReport $ht_developer "needs_developer.txt" "N";
    WriteReport $ht_releasedate "needs_releasedate.txt" "N";
    WriteReport $ht_players "needs_players.txt" "N";

    WriteReport $ht_video "needs_video.txt" "N"
    WriteReport $ht_marquee "needs_marquee.txt" "N"
    WriteReport $ht_image "needs_imagee.txt" "N"
    
    WriteReport $ht_perfect "perfect.txt" "N"
    


    #Media
    Write-Host -foregroundcolor cyan -backgroundcolor black  "Missing Video Node Count:" $ht_video.Count;
    Write-Host -foregroundcolor cyan -backgroundcolor black  "Missing image Node Count:" $ht_image.Count;
    Write-Host -foregroundcolor cyan -backgroundcolor black  "Missing marquee Node Count:" $ht_marquee.Count;

    #Metadata
    Write-Host -foregroundcolor Yellow -backgroundcolor black  "Missing genre Node Count:" $ht_genre.Count;
    Write-Host -foregroundcolor Yellow -backgroundcolor black  "Missing desc Node Count:" $ht_desc.Count;
    Write-Host -foregroundcolor green -backgroundcolor black  "Missing publisher Node Count:" $ht_publisher.Count;
    Write-Host -foregroundcolor green -backgroundcolor black  "Missing developer Node Count:" $ht_developer.count;
    Write-Host -foregroundcolor green -backgroundcolor black  "Missing releasedate Node Count:" $ht_releasedate.Count;
    Write-Host -foregroundcolor green -backgroundcolor black  "Missing players Node Count:" $ht_players.Count;
     
    #perfect 
    Write-Host -foregroundcolor red -backgroundcolor black  "perfect Count:" $ht_perfect.Count;
    

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving ReportMissingNodeCounts()"

}

#************************************WRITE_REPORT********************************************
function WriteReport($htList, [string] $fname, [string] $LaunchInNotepad)
{
    #Setup Report Dir, Make sure it exists
    [string] $reportsDir = [System.IO.Path]::GetDirectoryName($global:Path2GamesListXML);
    $reportsDir=$reportsDir+"\r\";

    $retVal = Test-Path -LiteralPath  $reportsDir -PathType Container #LiteralPath is required to stop interpreting special characters like ![], etc.
    if ($retVal -eq $false)
    {
        New-Item -ItemType Directory -Force -Path $reportsDir #Create the Dir
    }

    #Now Create Empty Reports File
    [string] $reportsFileName = $reportsDir + $fname;
    $retVal = Test-Path -Path $reportsFileName;
    if ($retVal -eq $false)
    {
        New-Item -Path $reportsFileName -ItemType File
    }
    Clear-Content $reportsFileName #Clear File Contents

    Write-Host -foregroundcolor Magenta -backgroundcolor black "Writing Report" $fname
    foreach($t in $htList.GetEnumerator() | Sort Name)
    { 
        #$rowStr = $t.Name + " : " + $t.value;
        $rowStr = $t.Name
        Write-Host -foregroundcolor Cyan -backgroundcolor black  $rowStr
        Add-Content -Path $reportsFileName -Value $rowStr
    }

    if ($LaunchInNotepad -eq "Y")
    {
        & 'notepad.exe' $reportsFileName
    }

    return;
}



#*****************************************************************************************************************************************
#Main Execution Begins Here
#*****************************************************************************************************************************************

Clear-Host

InitReg
#AskUserGamesListXML #Comment this line out to speed things up, once in reg if not needed to change. When you want to change call this again

Clear-Host
Write-Host -foregroundcolor green -backgroundcolor black "Source gameslist.xml"
Write-Host -foregroundcolor green -backgroundcolor black "$global:Path2GamesListXML"
Write-Host

$global:ConsoleDir =Split-Path -Path $global:Path2GamesListXML
Set-Location -Path $global:ConsoleDir #Change Dir to Root of Console Dir

Write-Host -foregroundcolor Yellow -backgroundcolor black "Console Dir"
Write-Host -foregroundcolor Yellow -backgroundcolor black $global:ConsoleDir
Write-Host

Write-Host -foregroundcolor Cyan -backgroundcolor black "Target Image Path"
$global:ImagePath="$global:ConsoleDir\m\"
Write-Host -foregroundcolor Cyan -backgroundcolor black $global:ImagePath
Write-Host




#Verify the gameslist.xml File Exists First
if (!(Test-Path -LiteralPath $global:Path2GamesListXML))
{ 
    HandleError "Unable to find gameslist.xml file:$global:Path2GamesListXML"
}


#Errors/Validation First
ScanGamesList4DuplicateNodes #Double Image nodes or double video nodes - Exit on Error if we hit this.
ScanGamesList4MissingFiles #Exit on Error if problem here as well.
ScanForRomsMissingInGamesList

#WARNINGS HERE
Scan4OrphanedVideos
Scan4OrphanedImages

#Reporting Last
ReportMissingNodeCounts

