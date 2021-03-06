'*****************************************************************
'**  Media Browser Roku Client - Music List Page
'*****************************************************************


'**********************************************************
'** Show Music List Page
'**********************************************************


Function ShowMusicListPage() As Integer

    ' Create Poster Screen
    screen = CreatePosterScreen("", "Music", "arced-square")

    ' Initialize Music Metadata
    MusicMetadata = InitMusicMetadata()

    screen.Categories(["Albums","Artists","Genres"])

    ' Fetch Default Data
    musicData = MusicMetadata.GetAlbums()

    if musicData = invalid
        createDialog("Problem Loading Music Albums", "There was an problem while attempting to get the list of music albums from the server.", "Continue")
    end if

    ' Set Content
    screen.Screen.SetContentList(musicData)

    ' Show Screen
    screen.Show()

    while true
        msg = wait(0, screen.Screen.GetMessagePort())

        if type(msg) = "roPosterScreenEvent" Then
            If msg.isListFocused() Then
                category = msg.GetIndex()

                ' Setup Message
                screen.Screen.SetContentList([])
                screen.Screen.SetFocusedListItem(0)
                screen.Screen.ShowMessage("Retrieving")

                ' Fetch Category (0 = Albums; 1 = Artists; 2 = Genres)
                if category = 0
                    musicData = MusicMetadata.GetAlbums()
                    if musicData = invalid
                        createDialog("Problem Loading Music Albums", "There was an problem while attempting to get the list of music albums from the server.", "Continue")
                    end if

                else if category = 1
                    musicData = MusicMetadata.GetArtists()
                    if musicData = invalid
                        createDialog("Problem Loading Music Artists", "There was an problem while attempting to get the list of music artists from the server.", "Continue")
                    end if

                else if category = 2
                    musicData = MusicMetadata.GetGenres()
                    if musicData = invalid
                        createDialog("Problem Loading Music Genres", "There was an problem while attempting to get the list of music genres from the server.", "Continue")
                    end if

                else
                    musicData = []
                end if

                screen.Screen.SetContentList(musicData)

                screen.Screen.ClearMessage()
            Else If msg.isListItemSelected() Then
                selection = msg.GetIndex()

                If musicData[selection].ContentType = "Album" Then
                    ShowMusicSongPage(musicData[selection])

                Else If musicData[selection].ContentType = "Artist" Then
                    ShowMusicAlbumPage(musicData[selection])

                Else If musicData[selection].ContentType = "Genre" Then
                    ShowMusicGenrePage(musicData[selection].Id)

                Else 
                    Print "Unknown Type found"
                End If

            Else If msg.isScreenClosed() then
                return -1
            End If
        end if
    end while

    return 0
End Function
