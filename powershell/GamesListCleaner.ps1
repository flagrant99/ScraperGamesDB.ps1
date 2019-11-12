#*****************************************************************************************************************************************
#This is the PowerShell Script For Cleaning up gamelist.xml for RetroPie
#It seems deleting a game from within edit metadata in the UI does not remove the element from gamelist.xml or game the art.
#This is especially concerning with Video Preview. 
#v2019-07-07
#Changing to assume new m for media folder with subfolders, instead of single images folder.
#*****************************************************************************************************************************************

#*****************************************************************************************************************************************
#To Use set Global Vars INPUT to change source target files
#*****************************************************************************************************************************************

$global:Path2GamesListXML = "D:\_GAMES\RetroPI\roms\XXX\gamelist.xml"
$global:WriteFileName = "gamelist.xml"


# ****************************************************************************************************************************
# HANDLE ERROR
# ****************************************************************************************************************************
function HandleError([string] $ErrMsg)
{
    Write-Host -foregroundcolor red -backgroundcolor black $ErrMsg
    Exit #Stop Execution of the script
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


# ****************************************************************************************************************************
# Description Nodes to Ascii (Changes written to $global:WriteFileName)
# For some reason the Description Nodes have wierd encodings on lots of characters in the gameslist.xml from the linux box.
# For example there are many space characters listed as 00 20. When I write these out from windows they are converted to  Â….
# Personally I think these are corrupt. Most of the space characters in the linux file are normal 20. No idea why sometimes there are NULLS before them.
# There are also lots of isses with special UTF-8 chars not getting converted right. So I just want this crap scrubbed down to ascii to make it easier for me to diff. 
# The Description is NOT super important to me anyway. Unknown chars converted to ??.
# Do this once after a full scrape. Then start running other functions cleanup.
# ****************************************************************************************************************************
function Description2Ascii()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }


    
    Write-Host -foregroundcolor green -backgroundcolor black "Entering Description2Ascii()"
    Write-Host -foregroundcolor green -backgroundcolor black $xw.gameList.game.Count " games in gameslist"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $asciiStr=""

        if ($gameNode.desc.count -gt 0)
        {
            $asciiStr = makeASCIIStr $gameNode.desc
            if ($asciiStr -ne  $gameNode.desc)
            {
                $gameNode.desc = $asciiStr
            }
        }

        if ($gameNode.publisher.count -gt 0)
        {
            $asciiStr=""
            $asciiStr = makeASCIIStr $gameNode.publisher
            if ($asciiStr -ne  $gameNode.publisher)
            {
                $gameNode.publisher = $asciiStr
            }
        }

        if ($gameNode.developer.count -gt 0)
        {
            $asciiStr=""
            $asciiStr = makeASCIIStr $gameNode.developer
            if ($asciiStr -ne  $gameNode.developer)
            {
                $gameNode.developer = $asciiStr
            }
        }


        if ($gameNode.name.count -gt 0)
        {
            $asciiStr=""
            $asciiStr = makeASCIIStr $gameNode.name
            if ($asciiStr -ne  $gameNode.developer)
            {
                $gameNode.name = $asciiStr
            }
        }

    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black "Leaving Description2Ascii()"
}


# ****************************************************************************************************************************
# So I am tired of everything being in an images folder.
# I am making a new m for media folder.
# Under this we will have 
# marquee
# video
# screen
# wheel
# mixart
# bezel
# etc. 
# As you can see this is a much better layout for different kinds of front end media. 
# This function should simply convert from the old to the new way
# ****************************************************************************************************************************
function RemapFromImages2m()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }



    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in RemapFromImages2m()"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        
        #Remap image
        $imagePath = ""
        $imagePath = $gameNode.image
        if ($imagePath.length -gt 1)
        {

            $FileName = [System.IO.Path]::GetFileName($imagePath);
            $NewPath = "./m/screen/$FileName"; #From ./images/ to ./m/screen/

            if (Test-Path -LiteralPath $NewPath)
            {
                $gameNode.image=$NewPath;
            }
        }


        #Remap marquee
        $imagePath = ""
        $imagePath = $gameNode.marquee
        if ($imagePath.length -gt 1)
        {

            $FileName = [System.IO.Path]::GetFileName($imagePath);
            $NewPath = "./m/marquee/$FileName"; #From ./images/ to ./m/marquee/

            if (Test-Path -LiteralPath $NewPath)
            {
                $gameNode.marquee=$NewPath;
            }
        }

        #Remap video
        $imagePath = ""
        $imagePath = $gameNode.video
        if ($imagePath.length -gt 1)
        {

            $FileName = [System.IO.Path]::GetFileName($imagePath);
            $NewPath = "./m/video/$FileName"; #From ./images/ to ./m/video/

            if (Test-Path -LiteralPath $NewPath)
            {
                $gameNode.video=$NewPath;
            }
        }


    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black " Leaving RemapFromImages2m()"
}



# ****************************************************************************************************************************
# Remove game nodes in gameslist.xml where the path no longer exists.
# If you remove a rom directly or through emulation station ui it never cleans up the game nodes or the game art.
# Seems especially strange since Delete in Emulation Station UI is under the metadata menu. So it deletes the rom and does NOT delete the metadata.
# I would have thought the opposite would occur.
# This iterates all game nodes and tests that rom paths. If they don't exist they are removed from $global:WriteFileName
# ****************************************************************************************************************************
function RemoveUnusedGameNodes()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }



    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in RemoveUnusedGameNodes()"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $retVal = Test-Path -LiteralPath  $gamePath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
        if ($retVal -eq $false)
        {
            Write-Host $gamePath -foregroundcolor red
            $gameNode.ParentNode.RemoveChild($gameNode);
        }
    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();
   Write-Host -foregroundcolor green -backgroundcolor black " Leaving RemoveUnusedGameNodes()"
}

# ****************************************************************************************************************************
# If the Path Pointed to by Image Node does not exist remove the image node
# ****************************************************************************************************************************
function RemoveBadImageNodes()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }



    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in RemoveBadImageNodes()"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $imagePath = ""
        $imagePath = $gameNode.image
        if ($imagePath.length -lt 1)
        {
            continue;
        }

        if (!(Test-Path -LiteralPath $imagePath))
        {
            #Remove Child Image Nodes
            $imageNode = $gameNode.SelectNodes("image")[0];
            
             $gameNode.RemoveChild( $imageNode)
        }
    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black " Leaving RemoveBadImageNodes()"
}


# ****************************************************************************************************************************
# If the Path Pointed to by Video Node does not exist remove the Video node
# ****************************************************************************************************************************
function RemoveBadVideoNodes()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }



    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in RemoveBadVideoNodes()"

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
            #Remove Child Image Nodes
            Write-Host -foregroundcolor green -backgroundcolor black "Removing $videoPath"
            $videoNode = $gameNode.SelectNodes("video")[0];
            
             $gameNode.RemoveChild( $videoNode)
        }
    }

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black " Leaving RemoveBadVideoNodes()"
}


# ****************************************************************************************************************************
# Add Missing game nodes in gameslist.xml where the ROM exists but there is no Node.
# This only add game node with name and path. Images and Video needs to be dealt with seperately.
# Initially I was going to deal with video and image here, but I see some game nodes not mapped to already existing image, video
# so we need seperate functions for that.
#
#$extFilter should be *.zip or *.a26, etc.
# ****************************************************************************************************************************
function AddMissingGameNodes($extFilter)
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in AddMissingGameNodes()"

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
   $FilesArr = get-childitem -Recurse -Path $global:ConsoleDir -include $extFilter

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
        {   #In here if the gameslist.xml does not have our path
            #Create a new game node
            $gameNode = $xw.CreateElement("game")

            $pathNode = $xw.CreateElement("path")
            $pathNode.InnerText = $RelativeName
            $gameNode.AppendChild($pathNode);

            $nameNode = $xw.CreateElement("name")
            $nameNode.InnerText = $fileTitle
            $gameNode.AppendChild($nameNode);


            $xw.gameList.AppendChild($gameNode)
            #Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)


   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black " Leaving AddMissingGameNodes()"
}


# ****************************************************************************************************************************
# I have seen Videos that exist are not being linked to.
# scan all videos and if not in gameslist.xml add them.
# ****************************************************************************************************************************
function AddMissingVideoNodesToExistingVideos()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in AddMissingVideoNodesToExistingVideos()"


    #Create $htVideoKeys so we have a hashTable with relative video path in Keys, I am putting Path to Zip in value in case we need to use it as key later.
    $htVideoKeys = @{}

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
   $FilesArr = get-childitem -Recurse -Path $global:VideoPath -include *.mp4
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
            #We need to find our game node and add a video child
            
            $Matching_Game_Node = $null
            $gameName = $fileTitle.replace("-video", "")

            Foreach($gameNode in $xw.gameList.game)
            {
                #$gamenode.name is not reliable, use zip title.
                $zipTitle = [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path);
                if ($zipTitle -eq $gameName)
                {
                    $Matching_Game_Node = $gameNode
                    break
                }
            }

            if ($Matching_Game_Node -eq $null)
            {
                continue;#Nothing we can do
            }

            $videoNode = $xw.CreateElement("video")
            if (Test-Path -LiteralPath $RelativeName)
            {#Here if Video is already there. Scraper left image and video but did not make nodes

                $videoNode.InnerText = $RelativeName
                $Matching_Game_Node.AppendChild($videoNode);
            }

            

            #Gmae Node should already be in games list so NO idea why I would do the below.
            #$xw.gameList.AppendChild($Matching_Game_Node)
            #Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)


   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black "Leaving AddMissingVideoNodesToExistingVideos()"

}


# ****************************************************************************************************************************
# I have seen Images that exist are not being linked to.
# scan all jpg Images and if not in gameslist.xml add them. (Does not work with png for now)
# ****************************************************************************************************************************
function AddMissingImageNodesToExistingImages()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in AddMissingImageNodesToExistingImages()"

    #Create $htImageKeys so we have a hashTable with relative Image path in Keys, I am putting Path to Zip in value in case we need to use it as key later.
    $htImageKeys = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $imagePath = ""
        $imagePath = $gameNode.image
        if ($imagePath.length -lt 1)
        {
            continue;
        }

        if (!(Test-Path -LiteralPath $imagePath))
        {
            HandleError("$imagePath does not exist") #If this happens signal problem!
            exit
        }

        if (!$htImageKeys.ContainsKey($imagePath))
        {
            $htImageKeys.Add($imagePath, $gamePath);
        }
    }#end of Foreach($gameNode in $xw.gameList.game) 

    Write-Host -foregroundcolor green -backgroundcolor black $htImageKeys.Keys.Count " Image Nodes"
   

   #Now lets get list of Image files in Image Dir
   $FilesArr = get-childitem -Recurse -Path $global:ScreenPath -include *.jpg
   Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " jpg's"

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
        {   #In here if the gameslist.xml does not have our image but it exists!
            #We need to find our game node and add an image child (or replacing existing one)
            
            $Matching_Game_Node = $null
            $gameName = $fileTitle.replace("-image", "")

            Foreach($gameNode in $xw.gameList.game)
            {
                $zipTitle = [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path);
                if ($zipTitle -eq $gameName)
                {
                    $Matching_Game_Node = $gameNode
                    break
                }
            }

            if ($Matching_Game_Node -eq $null)
            {
                continue;#Nothing we can do
            }

            if (Test-Path -LiteralPath $RelativeName)
            {#Here if Image Exists!
                if ($Matching_Game_Node.image.count -lt 1)
                {
                    $imageNode = $xw.CreateElement("image")
                    $imageNode.InnerText = $RelativeName
                    $Matching_Game_Node.AppendChild($imageNode);
                }
                else
                {
                    $Matching_Game_Node.image = $RelativeName
                }
            }

            


            #$xw.gameList.AppendChild($gameNode)
            #Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)


   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black "exiting AddMissingImageNodesToExistingImages()"
}



# ****************************************************************************************************************************
# I have seen Images that exist are not being linked to.
# scan all png Images and if not in gameslist.xml add them. (Does not work with jpg)
# ****************************************************************************************************************************
function AddMissingMarqueeNodesToExistingMarquees()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in AddMissingMarqueeNodesToExistingMarquees()"

    #Create $htImageKeys so we have a hashTable with relative Image path in Keys, I am putting Path to Zip in value in case we need to use it as key later.
    $htImageKeys = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $marqueePath = ""
        $marqueePath = $gameNode.marquee
        if ($marqueePath.length -lt 1)
        {
            continue;
        }

        if (!(Test-Path -LiteralPath $marqueePath))
        {
            HandleError("$marqueePath does not exist") #If this happens signal problem!
            exit
        }

        if (!$htImageKeys.ContainsKey($marqueePath))
        {
            $htImageKeys.Add($marqueePath, $gamePath);
        }
    }#end of Foreach($gameNode in $xw.gameList.game) 

    Write-Host -foregroundcolor green -backgroundcolor black $htImageKeys.Keys.Count " Image Nodes"
   

   #Now lets get list of Image files in Image Dir
   $FilesArr = get-childitem -Recurse -Path $global:MarqueePath -include *.png
   Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " png's"

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
            
            $Matching_Game_Node = $null
            $gameName = $fileTitle.replace("-marquee", "")

            Foreach($gameNode in $xw.gameList.game)
            {
                $zipTitle = [System.IO.Path]::GetFileNameWithoutExtension($gameNode.path);
                if ($zipTitle -eq $gameName)
                {
                    $Matching_Game_Node = $gameNode
                    break
                }
            }

            if ($Matching_Game_Node -eq $null)
            {
                continue;#Nothing we can do
            }

            $marqueeNode = $xw.CreateElement("marquee")
            if (Test-Path -LiteralPath $RelativeName)
            {#Here if Video is already there. Scraper left image and video but did not make nodes

                $marqueeNode.InnerText = $RelativeName
                $Matching_Game_Node.AppendChild($marqueeNode);
                Write-Host -foregroundcolor red -backgroundcolor yellow $RelativeName
            }

            


           #$xw.gameList.AppendChild($gameNode)
            #Write-Host -foregroundcolor red -backgroundcolor black $RelativeName
        }#end of if (!$htPathKeys.ContainsKey($RelativeName))
        
        
        
    }#end of foreach($file in $FilesArr)


   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor yellow -backgroundcolor black "Leaving AddMissingMarqueeNodesToExistingMarquees()"

}


# ****************************************************************************************************************************
# Move unused images, and video previews from the m(edia) to the u(nused) folder
#
# For now this guy is just listing unused stuff and to my surprise we have LOTS of video for real ROMS that are not in gameslist.xml
# This means we need to get gameslist.xml in to shape BEFORE we clean this guy up.
# In Other words we need to add AddMissingRomNodes() First.
# ****************************************************************************************************************************
function MoveUnsedImageArt()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in RemoveUnsedImageArt()"

    $htImgPaths = @{}
    $htVideoPaths = @{}

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        #$gamePath = $gameNode.Path
        
        $imageFileName = [System.IO.Path]::GetFileName($gameNode.image);

        if ($imageFileName.Length -gt 0)
        {
            if ($htImgPaths.ContainsKey($imageFileName) -eq $false)
            {
                $htImgPaths.Add($imageFileName, $imageFileName);
            }
        }


        $imageFileName = [System.IO.Path]::GetFileName($gameNode.marquee);

        if ($imageFileName.Length -gt 0)
        {
            if ($htImgPaths.ContainsKey($imageFileName) -eq $false)
            {
                $htImgPaths.Add($imageFileName, $imageFileName);
            }
        }

        $videoFileName = [System.IO.Path]::GetFileName($gameNode.video);

        if ($videoFileName.Length -gt 0)
        {
            $htVideoPaths.Add($videoFileName, $videoFileName);
        }


    }#end of Foreach($gameNode in $xw.gameList.game)

     Write-Host -foregroundcolor green -backgroundcolor black $htImgPaths.Count " unique image file titles gameslist.xml"
   
   #Now lets get list of files in Images Dir
   $FilesArr = get-childitem -File -Recurse -Path $global:ImagePath -Exclude *.txt
   
    Write-Host $FilesArr.Length;


    #Iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name
        #$fileName = [System.IO.Path]::GetFileName($FileName).ToLower();

        $parentDirTitle = [System.IO.Path]::GetFileNameWithoutExtension($file.Directory);
        if ($parentDirTitle -eq "wheel")#Ignore if Parent Dir is wheel I am using those for attractmode
        {
            continue;
        }

        if ($parentDirTitle -eq "mixart")#ignore mixart might use later.
        {
            continue;
        }


        $MatchFound = "NO"

        if ($htImgPaths.ContainsKey($FileName))
        {
            $MatchFound = "YES"
        }

        if ($htVideoPaths.ContainsKey($FileName))
        {
            $MatchFound = "YES"
        }



        if ($MatchFound -eq "NO")
        {
            Write-Host -foregroundcolor red -backgroundcolor black "MOVING UNUSED MEDIA FILE"
            Write-Host -foregroundcolor red -backgroundcolor black $fileTitle
            Write-Host -foregroundcolor yellow -backgroundcolor black $file.FullName
            $targetFname = $file.FullName.Replace("\m\", "\u\");
            $targetDir = [System.IO.Path]::GetDirectoryName($targetFname);
            Move-Item -LiteralPath $file.FullName -Destination $targetFname
            #$file.MoveTo($targetDir);
        }

    }#end of foreach($file in $FilesArr)

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving RemoveUnsedImageArt()"
}



# ****************************************************************************************************************************
# Scan for game nodes in gameslist.xml where the path no longer exists.
# Try to find new location and update path only
# ****************************************************************************************************************************
function ReLocateUnusedGameNodes()
{
    #Open Results File as XML
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }



    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist ReLocateUnusedGameNodes()"

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $retVal = Test-Path -LiteralPath  $gamePath -PathType leaf #LiteralPath is required to stop interpreting special characters like ![], etc.
        if ($retVal -eq $false)
        {
            Write-Host $gamePath -foregroundcolor red
            $fileName = [System.IO.Path]::GetFileName($gamePath);
            
            #Scan for File Name
            $FilesArr = get-childitem -LiteralPath $global:ConsoleDir -Filter "$fileName" -Recurse -File #Important use -Filter here NOT -Include.
            if ($FilesArr.Count -gt 1)
            {
                $FilesArr
                HandleError("More than one file")
            }
            if ($FilesArr.Count -eq 0)
            {
                continue
            }

            $f = $FilesArr[0];
            $FullName= $f.FullName
            $PartialName = $FullName.Substring($global:ConsoleDir.Length)
            $PartialName = $PartialName.Replace('\', '/')
            $RelativeName = ".$PartialName"

            Write-Host -foregroundcolor green -backgroundcolor black "Relocating $gamePath to $RelativeName"
            $gameNode.Path=$RelativeName

        }#end of if ($retVal -eq $false)
    }#end of Foreach($gameNode in $xw.gameList.game)

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

   Write-Host -foregroundcolor green -backgroundcolor black "Leaving ReLocateUnusedGameNodes()"
}



# ****************************************************************************************************************************
# Hand Brake for some reason capitalized file names. Linux is case sensitive. Make all mp4 file names lower case.
# ****************************************************************************************************************************
function mp4FileNamesToLower()
{
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white "mp4FileNamesToLower()"

   
    

   #Now lets get list of Video files in Image Dir
   $FilesArr = get-childitem -Recurse -Path $global:VideoPath -include *.mp4
   Write-Host -foregroundcolor green -backgroundcolor black $FilesArr.Length " mp4's"

    #Iterate Each $FilesArr >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    foreach($file in $FilesArr)
    {
        $FileName = $file.Name.ToLower();
        $FullName = $file.FullName
        Write-Host "$FullName $FileName"
        Rename-Item $FullName $FileName
    }#end of foreach($file in $FilesArr)

    return;
}


# ****************************************************************************************************************************
# So the Game Name in GamesList.xml is and should be the long correct name of the game. 
# Unfortunately the zip file name of the game is often hard to determine from this long Game Name.
# So I want it displayed in the Emulation Station GUI. I figured a quick way would be to apppend to Developer. 
# If $Add = "Y" then we will verify developer node ends with FileTitle else we will ensure developer does not end with FileTitle.
# This way we can easily revert if we don't want it there or we are done organizing.
# ****************************************************************************************************************************
function InjectFileTitleIntoDeveloper([string] $AddFlag)
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in InjectFileTitleIntoManufacturer()"

    #iterate each game Node >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path;
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($gamePath);
        $formattedTitle = "($fileTitle)";

        $developer = "";
        $developer = $gameNode.developer;

        $name = "";
        $name = $gameNode.name;
        

        if ($developer -eq $null)
        {
            $developerNode = $xw.CreateElement("developer")
            $gameNode.AppendChild($developerNode);
            $developer = "";
            Write-Host -foregroundcolor red -backgroundcolor yellow "Adding developer node for $gamePath"
        }

        if ($AddFlag -eq "Y")
        { #Add Title to developer Node
            if ($developer.EndsWith($formattedTitle) -eq $true)
            {
                continue;#Leave it all set
            }

            $new_developer = "$developer $formattedTitle";
            $new_developer = $new_developer.Trim();
            $gameNode.developer = $new_developer
        }
        else 
        { #Remove Title from developer node
            if ($developer.EndsWith($formattedTitle) -eq $false)
            {
                continue;#Leave it all set
            }

            $new_developer = $developer.Replace($formattedTitle, "");
            $new_developer = $new_developer.Trim();
            $gameNode.developer = $new_developer
        }


    }#end of Foreach($gameNode in $xw.gameList.game) >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving InjectFileTitleIntoDeveloper()";
    return;
}


# ****************************************************************************************************************************
# Iterate each game node and scan for empty subnodes after trim. If empty remove empty node.
# A lot of my code assumes the node existance implys something valid. Empty nodes are as good as nothing, so make it obvious.
# ****************************************************************************************************************************
function PurgeEmptySubNodes()
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in PurgeEmptySubNodes()"

    #iterate each game Node >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    $gameNode = $null;
    Foreach($gameNode in $xw.gameList.game)
    {
    
        PurgeEmptyNode "name" $gameNode;
        PurgeEmptyNode "desc" $gameNode;
        PurgeEmptyNode "image" $gameNode;
        PurgeEmptyNode "video" $gameNode;
        PurgeEmptyNode "marquee" $gameNode;
        PurgeEmptyNode "releasedate" $gameNode;
        PurgeEmptyNode "developer" $gameNode;
        PurgeEmptyNode "publisher" $gameNode;
        PurgeEmptyNode "players" $gameNode;
        PurgeEmptyNode "genre" $gameNode;

    }#end of Foreach($gameNode in $xw.gameList.game) >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

   
   $utf8 = New-Object System.Text.UTF8Encoding($false) #$false or #true to indicate if BOM is included.
   $sw = New-Object System.IO.StreamWriter($global:WriteFullPath, $false, $utf8)#2nd arg indicates append
   $xw.Save($sw);
   $sw.Close();

    Write-Host -foregroundcolor green -backgroundcolor black "Leaving InjectFileTitleIntoDeveloper()";
    return;
}

# ****************************************************************************************************************************
#
# ****************************************************************************************************************************
function PurgeEmptyNode([string] $subname, [System.Xml.XmlElement] $gNode)
{
    $subNode = $gameNode.SelectSingleNode($subname);
    if ($subNode -eq $null)
    {
        return;
    }

    $contentStr = $subNode.InnerText;
    $contentStr = $contentStr.Trim();
    if ($contentStr.Length -lt 1)
    {
        $gameNode.RemoveChild($subNode);
    }


    return;
}




# ****************************************************************************************************************************
# If no Image Node and/or No existing Image copy it over from old Images. After this step we can call AddMissingImageNodesToExistingImages to wire them up.
# This guy also converts from png to jpg
# ****************************************************************************************************************************
function IfMissingImageNodeCopyOldImage([string] $oldScreenShotsDir)
{
    #Open Source gameslist.xml
    [xml] $xw = $null
    $xw = Get-Content $global:Path2GamesListXML
    if ($xw -eq $null)
    {
        HandleError "Unable to open results xml file $global:Path2GamesListXML as xml"
    }

    
    Write-Host -foregroundcolor DarkBlue -backgroundcolor white $xw.gameList.game.Count " games in gameslist in IfMissingImageNodeCopyOldImage()"
    Write-Host -foregroundcolor green -backgroundcolor black $xw.gameList.game.Count "$oldScreenShotsDir"
    

    #iterate each game Node
    Foreach($gameNode in $xw.gameList.game)
    {
        $gamePath = $gameNode.Path
        $fileTitle = [System.IO.Path]::GetFileNameWithoutExtension($gamePath)
        $imagePath = ""
        $imagePath = $gameNode.image

        $DoTheCopy = "N";

        if ($imagePath.length -lt 1)
        {   #image NODE does not exist
            $DoTheCopy = "Y";
            Write-Host -foregroundcolor red -backgroundcolor black "Image Node not detected for $gamePath"
        }#end of if ($imagePath.length -lt 1)
        else
        {   #image NODE does exist!
            if (!(Test-Path -LiteralPath $imagePath))
            {
                $DoTheCopy = "Y";
            }
        }

        if ($DoTheCopy -ne "Y")
        {
            continue;#Do NOTHING
        }

            #Copy over ScreenShot from our old screen shots dir
            $newImageFname = "./images/$fileTitle-image.jpg"
            $oldScreenShotFileName = ""

            
            #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            #Try to find MATCHING OldScreenShotFileName
            $widlCards = $fileTitle+".png"#Try exact match first
            $FilesArr = get-childitem -LiteralPath $oldScreenShotsDir -Filter "$widlCards" #Important use -Filter here NOT -Include.
            if ($FilesArr.Count -lt 1)
            {
                $widlCards = $fileTitle+"*.png"
                $FilesArr = get-childitem -LiteralPath $oldScreenShotsDir -Filter "$widlCards" #Important use -Filter here NOT -Include.
                if ($FilesArr.Count -lt 1)
                {
                    $widlCards = $fileTitle+"*.jpg"
                    $FilesArr = get-childitem -LiteralPath $oldScreenShotsDir -Filter "$widlCards" #Important use -Filter here NOT -Include.
                    if ($FilesArr.Count -lt 1)
                    {
                        HandleError("No FIles Found")
                    }
                }
            }

            if ($FilesArr.Count -gt 1)
            {
                HandleError("More than one file")
            }
            $f = $FilesArr[0];
            $oldScreenShotFileName= $f.FullName
            if (!(Test-Path -LiteralPath $newImageFname))
            {
                Write-Host -foregroundcolor yellow -backgroundcolor black "Image $newImageFname does not exist"
                if (Test-Path -LiteralPath $oldScreenShotFileName)
                {
                  $tgtName = "$global:ScreenPath$fileTitle" + "-image.jpg" 
                  Write-Host -foregroundcolor green -backgroundcolor black "old screen shot found $oldScreenShotFileName. Copying to: $tgtName"

#Convert from png to jpg
#Requires –Version 2.0
Add-Type -AssemblyName system.drawing
$imageFormat = "System.Drawing.Imaging.ImageFormat" -as [type]
$image = [drawing.image]::FromFile($oldScreenShotFileName)
$image.Save($tgtName, $imageFormat::jpeg)

                  #Copy-Item $oldScreenShotFileName $tgtName
#                  $srcName = "$global:ImagePath$fileTitle" + "0000.png"
                  
#                  Rename-Item $srcName $tgtName
                }
                else
                {
                    
                    HandleError("Old Screen Shot File Name Not Found: $oldScreenShotFileName");
                }
            }#end of if (!(Test-Path -LiteralPath $newImageFname))

        
    }#end of Foreach($gameNode in $xw.gameList.game) 

    Write-Host -foregroundcolor green -backgroundcolor black $htMissingImageKeys.Keys.Count " Games missing Image Nodes (Leaving IfMissingImageNodeCopyOldImage())"
   
}


#*****************************************************************************************************************************************
#Main Execution Begins Here
#*****************************************************************************************************************************************

Clear-Host

Write-Host -foregroundcolor green -backgroundcolor black "Source gameslist.xml"
Write-Host -foregroundcolor green -backgroundcolor black "$global:Path2GamesListXML"
Write-Host

$global:ConsoleDir =Split-Path -Path $global:Path2GamesListXML
Set-Location -Path $global:ConsoleDir #Change Dir to Root of Console Dir

Write-Host -foregroundcolor Yellow -backgroundcolor black "Console Dir"
Write-Host -foregroundcolor Yellow -backgroundcolor black $global:ConsoleDir
Write-Host

Write-Host -foregroundcolor Magenta -backgroundcolor black "Target gameslist.xml"
$global:WriteFullPath="$global:ConsoleDir\$global:WriteFileName"
Write-Host -foregroundcolor Magenta -backgroundcolor black $global:WriteFullPath
Write-Host

Write-Host -foregroundcolor Cyan -backgroundcolor black "Target Image Path"
$global:ImagePath="$global:ConsoleDir\m\"
$global:VideoPath="$global:ConsoleDir\m\video\";
$global:MarqueePath="$global:ConsoleDir\m\marquee\";
$global:ScreenPath="$global:ConsoleDir\m\screen\";

Write-Host -foregroundcolor Cyan -backgroundcolor black $global:ImagePath
Write-Host




#Verify the Result.xml File Exists First
if (!(Test-Path -LiteralPath $global:Path2GamesListXML))
{ 
    HandleError "Unable to find gameslist.xml file:$global:Path2GamesListXML"
}

#RemapFromImages2m

#For HandBrake Only
#mp4FileNamesToLower
#IfMissingImageNodeCopyOldImage "D:\_GAMES\PC\Emulation2003\Atari2600\ScreenShots"


#Always SAFE to RUN
PurgeEmptySubNodes
#Description2Ascii   #Convert gameslist.xml to ASCII First, ONCE before using below functions!
ReLocateUnusedGameNodes #Always Run this before RemoveUnusedGameNodes


AddMissingGameNodes "*.pbp" #zip, pbp
AddMissingVideoNodesToExistingVideos

RemoveBadImageNodes
AddMissingImageNodesToExistingImages #jpg only!
AddMissingMarqueeNodesToExistingMarquees #png Only

RemoveUnusedGameNodes
MoveUnsedImageArt  #No Longer Deletes Media Files, Just moves to u(nused) subfolder
  

#RemoveBadVideoNodes


#InjectFileTitleIntoDeveloper "N"



Write-Host -foregroundcolor yellow -backgroundcolor black "Finished Processing"
