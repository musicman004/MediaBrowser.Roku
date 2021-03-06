'*****************************************************************
'**  Media Browser Roku Client - Video Metadata
'*****************************************************************


'**********************************************************
'** Get Video Details
'**********************************************************

Function getVideoMetadata(videoId As String) As Object
    ' Validate Parameter
    if validateParam(videoId, "roString", "videometadata_details") = false return invalid

    ' URL
    url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/Items/" + HttpEncode(videoId)

    ' Prepare Request
    request = HttpRequest(url)
    request.ContentType("json")
    request.AddAuthorization()

    ' Execute Request
    response = request.GetToStringWithTimeout(10)
    if response <> invalid

        ' Fixes bug within BRS Json Parser
        regex         = CreateObject("roRegex", Chr(34) + "(RunTimeTicks|PlaybackPositionTicks|StartPositionTicks)" + Chr(34) + ":(-?[0-9]+)(}?]?),", "i")
        fixedResponse = regex.ReplaceAll(response, Chr(34) + "\1" + Chr(34) + ":" + Chr(34) + "\2" + Chr(34) + "\3,")

        i = ParseJSON(fixedResponse)

        if i = invalid
            Debug("Error Parsing Video Metadata")
            return invalid
        end if

        if i.Type = invalid
            Debug("No Content Type Set for Video")
            return invalid
        end if
        
        metaData = {}

        ' Set the Content Type
        metaData.ContentType = i.Type

        ' Set the Id
        metaData.Id = i.Id

        ' Set the Title
        metaData.Title = firstOf(i.Name, "Unknown")

        ' Set the Series Title
        if i.SeriesName <> invalid
            metaData.SeriesTitle = i.SeriesName
        end if

        ' Set the Overview
        if i.Overview <> invalid
            metaData.Description = i.Overview
        end if

        ' Set the Official Rating
        if i.OfficialRating <> invalid
            metaData.Rating = i.OfficialRating
        end if

        ' Set the Release Date
        if isInt(i.ProductionYear)
            metaData.ReleaseDate = itostr(i.ProductionYear)
        end if

        ' Set the Star Rating
        if i.CommunityRating <> invalid
            metaData.UserStarRating = Int(i.CommunityRating) * 10
        end if

        ' Set the Run Time
        if i.RunTimeTicks <> "" And i.RunTimeTicks <> invalid
            metaData.Length = Int(((i.RunTimeTicks).ToFloat() / 10000) / 1000)
        end if

        ' Set the Play Access
        metaData.PlayAccess = LCase(firstOf(i.PlayAccess, "full"))

        ' Set the Place Holder (default to is not a placeholder)
        metaData.IsPlaceHolder = firstOf(i.IsPlaceHolder, false)

        ' Set the Local Trailer Count
        metaData.LocalTrailerCount = firstOf(i.LocalTrailerCount, 0)

        ' Set the Playback Position
        if i.UserData.PlaybackPositionTicks <> "" And i.UserData.PlaybackPositionTicks <> invalid
            positionSeconds = Int(((i.UserData.PlaybackPositionTicks).ToFloat() / 10000) / 1000)
            metaData.PlaybackPosition = positionSeconds
        else
            metaData.PlaybackPosition = 0
        end if

        if i.Type = "Movie"

            ' Check For People, Grab First 3 If Exists
            if i.People <> invalid And i.People.Count() > 0
                metaData.Actors = CreateObject("roArray", 3, true)

                ' Set Max People to grab Size of people array
                maxPeople = i.People.Count()-1

                ' Check To Max sure there are 3 people
                if maxPeople > 3
                    maxPeople = 2
                end if

                for actorCount = 0 to maxPeople
                    if i.People[actorCount].Name <> "" And i.People[actorCount].Name <> invalid
                        metaData.Actors.Push(i.People[actorCount].Name)
                    end if
                end for
            end if

        else if i.Type = "Episode"

            ' Build Episode Information
            episodeInfo = ""

            ' Add Series Name
            if i.SeriesName <> invalid
                episodeInfo = i.SeriesName
            end if

            ' Add Season Number
            if i.ParentIndexNumber <> invalid
                if episodeInfo <> ""
                    episodeInfo = episodeInfo + " / "
                end if

                episodeInfo = episodeInfo + "Season " + itostr(i.ParentIndexNumber)
            end if

            ' Add Episode Number
            if i.IndexNumber <> invalid
                if episodeInfo <> ""
                    episodeInfo = episodeInfo + " / "
                end if
                
                episodeInfo = episodeInfo + "Episode " + itostr(i.IndexNumber)

                ' Add Double Episode Number
                if i.IndexNumberEnd <> invalid
                    episodeInfo = episodeInfo + "-" + itostr(i.IndexNumberEnd)
                end if
            end if

            ' Use Actors Area for Series / Season / Episode
            metaData.Actors = episodeInfo

        end if

        ' Setup Watched Status In Category Area and Played Flag
        if i.UserData.Played <> invalid And i.UserData.Played = true
            metaData.IsPlayed = true
            if i.UserData.LastPlayedDate <> invalid
                metaData.Categories = "Watched on " + formatDateStamp(i.UserData.LastPlayedDate)
            else
                metaData.Categories = "Watched"
            end if
        else
            metaData.IsPlayed = false
        end if

        ' Setup Favorite Status
        if i.UserData.IsFavorite <> invalid And i.UserData.IsFavorite = true
            metaData.IsFavorite = true
        else
            metaData.IsFavorite = false
        end if

        ' Setup Chapters
        if i.Chapters <> invalid

            metaData.Chapters = CreateObject("roArray", 5, true)
            chapterCount = 0

            for each c in i.Chapters
                chapterData = {}

                ' Set the chapter display title
                chapterData.Title = firstOf(c.Name, "Unknown")
                chapterData.ShortDescriptionLine1 = firstOf(c.Name, "Unknown")

                ' Set chapter time
                if c.StartPositionTicks <> invalid
                    chapterPositionSeconds = Int(((c.StartPositionTicks).ToFloat() / 10000) / 1000)

                    chapterData.StartPosition = chapterPositionSeconds
                    chapterData.ShortDescriptionLine2 = formatTime(chapterPositionSeconds)
                end if

                ' Get Image Sizes
                sizes = GetImageSizes("flat-episodic-16x9")

                ' Check if Chapter has Image, otherwise use default
                if c.ImageTag <> "" And c.ImageTag <> invalid
                    imageUrl = GetServerBaseUrl() + "/Items/" + HttpEncode(i.Id) + "/Images/Chapter/" + itostr(chapterCount)

                    chapterData.HDPosterUrl = BuildImage(imageUrl, sizes.hdWidth, sizes.hdHeight, c.ImageTag, false, 0, true)
                    chapterData.SDPosterUrl = BuildImage(imageUrl, sizes.sdWidth, sizes.sdHeight, c.ImageTag, false, 0, true)

                else 
                    chapterData.HDPosterUrl = "pkg://images/defaults/hd-landscape.jpg"
                    chapterData.SDPosterUrl = "pkg://images/defaults/sd-landscape.jpg"

                end if

                ' Increment Count
                chapterCount = chapterCount + 1

                metaData.Chapters.push( chapterData )
            end for

        end if

        ' Setup Video Location / Type Information
        if i.VideoType <> invalid
            metaData.VideoType = LCase(i.VideoType)
        end If

        if i.Path <> invalid
            metaData.VideoPath = i.Path
        end If

        if i.LocationType <> invalid
            metaData.LocationType = LCase(i.LocationType)
        else
            metaData.LocationType = "none"
        end If

        ' Set HD Flags
        if i.IsHd <> invalid
            metaData.HDBranded = i.IsHd
            metaData.IsHD = i.IsHd
        end if

        ' Parse Media Info
        metaData = parseVideoMediaInfo(metaData, i)

        ' Get Image Sizes
        if i.Type = "Episode"
            sizes = GetImageSizes("rounded-rect-16x9-generic")
        else
            sizes = GetImageSizes("movie")
        end if
        
        ' Check if Item has Image, otherwise use default
        if i.ImageTags.Primary <> "" And i.ImageTags.Primary <> invalid
            imageUrl = GetServerBaseUrl() + "/Items/" + HttpEncode(i.Id) + "/Images/Primary/0"

            metaData.HDPosterUrl = BuildImage(imageUrl, sizes.hdWidth, sizes.hdHeight, i.ImageTags.Primary, false, 0, true)
            metaData.SDPosterUrl = BuildImage(imageUrl, sizes.sdWidth, sizes.sdHeight, i.ImageTags.Primary, false, 0, true)

        else 
            if i.Type = "Episode"
                metaData.HDPosterUrl = "pkg://images/defaults/hd-landscape.jpg"
                metaData.SDPosterUrl = "pkg://images/defaults/sd-landscape.jpg"
            else
                metaData.HDPosterUrl = "pkg://images/defaults/hd-poster.jpg"
                metaData.SDPosterUrl = "pkg://images/defaults/sd-poster.jpg"
            end if

        end if

        return metaData
    else
        Debug("Failed to Get Video Metadata")
    end if

    return invalid
End Function


'**********************************************************
'** Parse Media Information
'**********************************************************

Function parseVideoMediaInfo(metaData As Object, video As Object) As Object

    ' Setup Video / Audio / Subtitle Streams
    metaData.audioStreams    = CreateObject("roArray", 2, true)
    metaData.subtitleStreams = CreateObject("roArray", 2, true)

    ' Determine Media Compatibility
    compatibleVideo        = false
    compatibleAudio        = false
    compatibleAudioStreams = {}
    foundVideo             = false
    foundDefaultAudio      = false
    firstAudio             = true
    firstAudioChannels     = 0
    defaultAudioChannels   = 0

    ' Get Video Bitrate
    maxVideoBitrate = firstOf(RegRead("prefVideoQuality"), "3200")
    maxVideoBitrate = maxVideoBitrate.ToInt()

    for each stream in video.MediaStreams

        if stream.Type = "Video" And foundVideo = false
            foundVideo = true
            streamBitrate = Int(stream.BitRate / 1000)
            streamLevel   = firstOf(stream.Level, 100) ' Default to very high value to prevent compatible video match
            streamProfile = LCase(firstOf(stream.Profile, "unknown")) ' Default to unknown to prevent compatible video match

            if (stream.Codec = "h264" Or stream.Codec = "AVC") And streamLevel <= 41 And (streamProfile = "main" Or streamProfile = "high") And streamBitrate < maxVideoBitrate
                compatibleVideo = true
            end if

            ' Determine Bitrate
            if streamBitrate > maxVideoBitrate
                metaData.streamBitrate = maxVideoBitrate
            else
                metaData.streamBitrate = streamBitrate
            end if

            ' Determine Full 1080p
            if stream.Height = 1080
                metaData.FullHD = true
            end if

            ' Determine Frame Rate
            if stream.RealFrameRate <> invalid
                if stream.RealFrameRate >= 29
                    metaData.FrameRate = 30
                else
                    metaData.FrameRate = 24
                end if

            else if stream.AverageFrameRate <> invalid
                if stream.RealFrameRate >= 29
                    metaData.FrameRate = 30
                else
                    metaData.FrameRate = 24
                end if

            end if

        else if stream.Type = "Audio" 

            if firstAudio
                firstAudio = false
                firstAudioChannels = firstOf(stream.Channels, 2)

                ' Determine Compatible Audio (Default audio will override)
                if stream.Codec = "aac" Or (stream.Codec = "ac3" And getGlobalVar("audioOutput51")) Or (stream.Codec = "dca" And getGlobalVar("audioOutput51") And getGlobalVar("audioDTS"))
                    compatibleAudio = true
                end if
            end if

            ' Use Default To Determine Surround Sound
            if stream.IsDefault
                foundDefaultAudio = true

                channels = firstOf(stream.Channels, 2)
                defaultAudioChannels = channels
                if channels > 5
                    metaData.AudioFormat = "dolby-digital"
                end if
                
                ' Determine Compatible Audio
                if stream.Codec = "aac" Or (stream.Codec = "ac3" And getGlobalVar("audioOutput51")) Or (stream.Codec = "dca" And getGlobalVar("audioOutput51") And getGlobalVar("audioDTS"))
                    compatibleAudio = true
                else
                    compatibleAudio = false
                end if
            end if

            ' Keep a list of compatible audio streams
            if stream.Codec = "aac" Or (stream.Codec = "ac3" And getGlobalVar("audioOutput51")) Or (stream.Codec = "dca" And getGlobalVar("audioOutput51") And getGlobalVar("audioDTS"))
                compatibleAudioStreams.AddReplace(itostr(stream.Index), true)
            else
                'compatibleAudioStreams.AddReplace(stream.Index, false)
            end if

            audioData = {}
            audioData.Title = ""

            ' Set Index
            audioData.Index = stream.Index

            ' Set Language
            if stream.Language <> invalid
                audioData.Title = formatLanguage(stream.Language)
            end if

            ' Set Description
            if stream.Profile <> invalid
                audioData.Title = audioData.Title + ", " + stream.Profile
            else if stream.Codec <> invalid
                audioData.Title = audioData.Title + ", " + stream.Codec
            end if

            ' Set Channels
            if stream.Channels <> invalid
                audioData.Title = audioData.Title + ", Channels: " + itostr(stream.Channels)
            end if

            metaData.audioStreams.push( audioData )

        else if stream.Type = "Subtitle" 

            subtitleData = {}
            subtitleData.Title = ""

            ' Set Index
            subtitleData.Index = stream.Index

            ' Set Language
            if stream.Language <> invalid
                subtitleData.Title = formatLanguage(stream.Language)
            end if

            metaData.subtitleStreams.push( subtitleData )

        end if

    end for

    ' If no default audio was found, use first audio stream
    if Not foundDefaultAudio
        defaultAudioChannels = firstAudioChannels
        if firstAudioChannels > 5
            metaData.AudioFormat = "dolby-digital"
        end if
    end if

    ' Set Video / Audio Compatibility
    metaData.CompatibleVideo        = compatibleVideo
    metaData.CompatibleAudio        = compatibleAudio
    metaData.CompatibleAudioStreams = compatibleAudioStreams

    ' Set the Default Audio Channels
    metaData.DefaultAudioChannels = defaultAudioChannels

    return metaData
End Function


'**********************************************************
'** Setup Video Playback
'**********************************************************

Function setupVideoPlayback(metadata As Object, options = invalid As Object) As Object

    ' Setup Video Playback
    videoType     = metadata.VideoType
    locationType  = metadata.LocationType
    rokuVersion   = getGlobalVar("rokuVersion")
    audioOutput51 = getGlobalVar("audioOutput51")
    supportsSurroundSound = getGlobalVar("surroundSound")

    ' Set Playback Options
    if options <> invalid
        audioStream    = firstOf(options.audio, false)
        subtitleStream = firstOf(options.subtitle, false)
        playStart      = firstOf(options.playstart, false)
    else
        audioStream    = false
        subtitleStream = false
        playStart      = false
    end if

    ' Setup Defaults
    metadata.IsAppleTrailer = false

    Print "Play Start: "; playStart
    Print "Audio Stream: "; audioStream
    Print "Subtitle Stream: "; subtitleStream

    if videoType = "videofile"
        extension = getFileExtension(metaData.VideoPath)

        if locationType = "remote"

            ' If Apple trailer, direct play
            regex = CreateObject("roRegex", "trailers.apple.com", "i")
            if regex.IsMatch(metaData.VideoPath)
                action = "direct"
                metadata.IsAppleTrailer = true
            else
                action = "transcode"
            end if

        else if locationType = "filesystem"

            if metadata.CompatibleVideo And ( (extension = "mp4" Or extension = "mpv") Or (extension = "mkv" And (rokuVersion[0] > 5 Or (rokuVersion[0] = 5 And rokuVersion[1] >= 1) ) ) )
                if (Not audioOutput51 And metaData.DefaultAudioChannels > 2) Or (audioStream Or subtitleStream)
                    if subtitleStream
                        action = "transcode"
                    else
                        action = "streamcopy"
                    end if
                else
                    if metadata.CompatibleAudio
                        action = "direct"
                    else
                        action = "streamcopy"
                    end if
                end if

            else
                if metadata.CompatibleVideo
                    action = "streamcopy"
                else
                    action = "transcode"
                end if
            end if

        else
            action = "transcode"
        end if

    else
        action = "transcode"
    end if

    Debug("Action For Video (" + metadata.Title + "): " + action)

    ' Get Video Bitrate
    videoBitrate = firstOf(RegRead("prefVideoQuality"), "3200")
    videoBitrate = videoBitrate.ToInt()

    streamParams = {}

    ' Direct Stream
    if action = "direct"
        streamParams.url = GetServerBaseUrl() + "/Videos/" + metadata.Id + "/stream." + extension + "?static=true"
        streamParams.bitrate = metadata.streamBitrate
        streamParams.contentid = "x-direct"

        ' Set Video Quality Depending Upon Display Type
        if getGlobalVar("displayType") = "HDTV"
            streamParams.quality = true
        else
            streamParams.quality = false
        end if

        if extension = "mkv"
            metaData.StreamFormat = "mkv"
        else
            metaData.StreamFormat = "mp4"
        end if
        metaData.Stream = streamParams

        ' Add Play Start
        if playStart
            metaData.PlayStart = playStart
        end if

        ' Set Direct Play Flag
        metaData.DirectPlay = true

        ' Setup Playback Method in Rating area
        metaData.Rating = "Direct Play (" + extension + ")"

    ' Stream Copy
    else if action = "streamcopy"
        ' Base URL
        url = GetServerBaseUrl() + "/Videos/" + HttpEncode(metadata.Id) + "/stream.m3u8"

        ' Default Settings
        query = {
            VideoCodec: "copy"
            TimeStampOffsetMs: "0"
            DeviceId: getGlobalVar("rokuUniqueId", "Unknown")
        }

        ' Set playback method for info box
        playbackInfo = "Copy Video;"

        ' Add Audio Settings
        if audioStream
            ' If the selected stream is compatible, then stream copy the audio
            if metaData.CompatibleAudioStreams.DoesExist(itostr(audioStream))
                audioSettings = {
                    AudioCodec: "copy"
                    AudioStreamIndex: itostr(audioStream)
                }

                playbackInfo = playbackInfo + " Copy Audio"
            else
                audioSettings = {
                    AudioCodec: "aac"
                    AudioBitRate: "128000"
                    AudioChannels: "2"
                    AudioStreamIndex: itostr(audioStream)
                }

                playbackInfo = playbackInfo + " Convert Audio"
            end if
        else
            audioSettings = {
                AudioCodec: "aac"
                AudioBitRate: "128000"
                AudioChannels: "2"
            }

            playbackInfo = playbackInfo + " Convert Audio"
        end if

        ' Add Audio Params to Query
        query = AddToQuery(query, audioSettings)

        ' Prepare Url
        request = HttpRequest(url)
        request.BuildQuery(query)

        ' Add Play Start
        if playStart
            playStartTicks = itostr(playStart) + "0000000"
            request.AddParam("StartTimeTicks", playStartTicks)
            metaData.PlayStart = playStart
        end if

        ' Add Subtitle Stream
        if subtitleStream then request.AddParam("SubtitleStreamIndex", itostr(subtitleStream))

        ' Prepare Stream
        streamParams.url = request.GetUrl()
        streamParams.bitrate = metadata.streamBitrate
        streamParams.contentid = "x-streamcopy"

        ' Set Video Quality Depending Upon Display Type
        if getGlobalVar("displayType") = "HDTV"
            streamParams.quality = true
        else
            streamParams.quality = false
        end if

        metaData.StreamFormat = "hls"
        metaData.SwitchingStrategy = "no-adaptation"
        metaData.Stream = streamParams

        ' Setup Playback Method in Rating area
        metaData.Rating = playbackInfo

    ' Transcode
    else
        ' Base URL
        url = GetServerBaseUrl() + "/Videos/" + HttpEncode(metadata.Id) + "/stream.m3u8"

        ' Default Settings
        query = {
            VideoCodec: "h264"
            TimeStampOffsetMs: "0"
            DeviceId: getGlobalVar("rokuUniqueId", "Unknown")
        }

        ' Add Video Settings
        videoSettings = getVideoBitrateSettings(videoBitrate)
        query = AddToQuery(query, videoSettings)

        ' Add Audio Settings
        if audioStream
            ' If the selected stream is compatible, then stream copy the audio
            if metaData.CompatibleAudioStreams.DoesExist(itostr(audioStream))
                audioSettings = {
                    AudioCodec: "copy"
                    AudioStreamIndex: itostr(audioStream)
                }
            else
                audioSettings = {
                    AudioCodec: "aac"
                    AudioBitRate: "128000"
                    AudioChannels: "2"
                    AudioStreamIndex: itostr(audioStream)
                }
            end if
        else
            audioSettings = {
                AudioCodec: "aac"
                AudioBitRate: "128000"
                AudioChannels: "2"
            }
        end if

        ' Add Audio Settings to Query
        query = AddToQuery(query, audioSettings)

        ' Prepare Url
        request = HttpRequest(url)
        request.BuildQuery(query)

        ' Add Play Start
        if playStart
            playStartTicks = itostr(playStart) + "0000000"
            request.AddParam("StartTimeTicks", playStartTicks)
            metaData.PlayStart = playStart
        end if

        ' Add Subtitle Stream
        if subtitleStream then request.AddParam("SubtitleStreamIndex", itostr(subtitleStream))

        ' Prepare Stream
        streamParams.url = request.GetUrl()
        streamParams.bitrate = videoBitrate

        ' Set Video Quality Depending Upon Display Type and Bitrate
        if videoBitrate > 700 And getGlobalVar("displayType") = "HDTV"
            streamParams.quality = true
        else
            streamParams.quality = false
        end if

        streamParams.contentid = "x-transcode"

        metaData.StreamFormat = "hls"
        metaData.SwitchingStrategy = "no-adaptation"
        metaData.Stream = streamParams

        ' Setup Playback Method in Rating area
        metaData.Rating = "Convert Video and Audio"

    end if

    Print streamParams.url

    return metaData
End Function


'**********************************************************
'** Post Video Playback
'**********************************************************

Function postVideoPlayback(videoId As String, action As String, position = invalid) As Boolean

    ' Format Position Seconds into Ticks
    if position <> invalid
        positionTicks =  itostr(position) + "0000000"
    end if

    if action = "start"
        ' URL
        url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayingItems/" + HttpEncode(videoId)

        ' Prepare Request
        request = HttpRequest(url)
        request.AddAuthorization()
        request.AddParam("CanSeek", "true")
    else if action = "progress"
        ' URL
        url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayingItems/" + HttpEncode(videoId) + "/Progress?PositionTicks=" + positionTicks

        ' Prepare Request
        request = HttpRequest(url)
        request.AddAuthorization()
    else if action = "pause"
        ' URL
        url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayingItems/" + HttpEncode(videoId) + "/Progress?IsPaused=true&PositionTicks=" + positionTicks

        ' Prepare Request
        request = HttpRequest(url)
        request.AddAuthorization()
    else if action = "resume"
        ' URL
        url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayingItems/" + HttpEncode(videoId) + "/Progress?IsPaused=false&PositionTicks=" + positionTicks

        ' Prepare Request
        request = HttpRequest(url)
        request.AddAuthorization()
    else if action = "stop"
        ' URL
        url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayingItems/" + HttpEncode(videoId) + "?PositionTicks=" + positionTicks

        ' Prepare Request
        request = HttpRequest(url)
        request.AddAuthorization()
        request.SetRequest("DELETE")
    end if

    ' Execute Request
    response = request.PostFromStringWithTimeout("", 5)
    if response <> invalid
        return true
    else
        Debug("Failed to Post Video Playback Progress")
    end if

    return false
End Function


'**********************************************************
'** Post Stop Transcode
'**********************************************************

Function postStopTranscode() As Boolean
    ' URL
    url = GetServerBaseUrl() + "/Videos/ActiveEncodings"

    ' Prepare Request
    request = HttpRequest(url)
    request.AddAuthorization()
    request.AddParam("DeviceId", getGlobalVar("rokuUniqueId", "Unknown"))
    request.SetRequest("DELETE")

    ' Execute Request
    response = request.PostFromStringWithTimeout("", 5)
    if response <> invalid
        return true
    else
        Debug("Failed to Post Stop Transcode")
    end if

    return false
End Function


'**********************************************************
'** Post Manual Watched Status
'**********************************************************

Function postWatchedStatus(videoId As String, markWatched As Boolean) As Boolean
    ' URL
    url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/PlayedItems/" + HttpEncode(videoId)

    ' Prepare Request
    request = HttpRequest(url)
    request.AddAuthorization()

    ' If marking as unwatched
    if Not markWatched
        request.SetRequest("DELETE")
    end if

    ' Execute Request
    response = request.PostFromStringWithTimeout("", 5)
    if response <> invalid
        Debug("Mark Played/Unplayed")
        return true
    else
        Debug("Failed to Post Manual Watched Status")
    end if

    return false
End Function


'**********************************************************
'** Post Favorite Status
'**********************************************************

Function postFavoriteStatus(videoId As String, markFavorite As Boolean) As Boolean
    ' URL
    url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/FavoriteItems/" + HttpEncode(videoId)

    ' Prepare Request
    request = HttpRequest(url)
    request.AddAuthorization()

    ' If marking as un-favorite
    if Not markFavorite
        request.SetRequest("DELETE")
    end if

    ' Execute Request
    response = request.PostFromStringWithTimeout("", 5)
    if response <> invalid
        Debug("Add/Remove Favorite")
        return true
    else
        Debug("Failed to Post Favorite Status")
    end if

    return false
End Function


'**********************************************************
'** Get Local Trailers
'**********************************************************

Function getLocalTrailers(videoId As String) As Object
    ' URL
    url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/Items/" + HttpEncode(videoId) + "/LocalTrailers"

    ' Prepare Request
    request = HttpRequest(url)
    request.ContentType("json")
    request.AddAuthorization()

    ' Execute Request
    response = request.GetToStringWithTimeout(10)
    if response <> invalid

        items = ParseJSON(response)

        if items = invalid
            Debug("Error while parsing JSON response for Local Trailers")
            return invalid
        end if

        ' Only Get First Trailer
        i = items[0]
        
        metaData = {}

        ' Fetch Full Video Metadata
        metaData = getVideoMetadata(i.Id)

        return metaData
    else
        Debug("Failed to Get Local Trailers")
    end if

    return invalid
End Function
