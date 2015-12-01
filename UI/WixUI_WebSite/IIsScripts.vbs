Option Explicit

Const ERROR_SUCCESS = 0 ' 1
Const ERROR_INSTALL_FAILURE = 1603 ' 3
Const msiMessageTypeError = &H1000000

'===========================================================================
' Function show error message box
'===========================================================================
Private Sub ShowErrorMessage(ByVal msg)
    If Err.Number <> 0 Then
        msg = msg & vbCrLf & _
         "Error Details: " & Err.Description & " [Number:" & Hex(Err.Number) & "]"
    End If
    
''********************** DEBUG **********************
'    If VBA Then
'        MsgBox msg, vbCritical, "Error"
'        Exit Sub
'    End If
''********************** DEBUG **********************

    Dim record
    Set record = Session.Installer.CreateRecord(0)
    record.StringData(0) = msg
    Session.Message msiMessageTypeError, record
End Sub

'===========================================================================
' This function validate virtual directory name
'===========================================================================
Public Function CheckVirtualDirectoryName()
    Dim oRegularExpression, sVirtualDirName, sWebSiteName, iMaxCharacters, sRegExPattern, aSegments, sSegment
    
    On Error Resume Next
    
    ' Set Defaults
    iMaxCharacters = 64
    
    ' Get Msi Installer properties
    sVirtualDirName = Session.Property("IIS_VIRTUALDIR")
    sWebSiteName = Session.Property("IIS_WEBSITE")

    ' Set default result
    Session.Property("IIS_CHECKVIRTUALDIR") = "0"
    CheckVirtualDirectoryName = ERROR_SUCCESS
    
    aSegments = Split(sVirtualDirName, "/", 8, vbTextCompare)
    For Each sSegment In aSegments
        If Len(sSegment) < 1 Or Len(sSegment) > iMaxCharacters Then
            ' Port is either not an integer or not in a valid range
            ShowErrorMessage "The virtual directory segment lenght must be from 1 to " + CStr(iMaxCharacters) + "."
            Exit Function
        End If
    
        ' Set regex params
        sRegExPattern = "[\\\/\""\|\<\>\:\*\?\[\]\+\=\;\,\@\&]"
        
        ' Prepare regex for virtural directory name
        Set oRegularExpression = CreateObject("vbscript.regexp") 'New RegExp
        oRegularExpression.Pattern = sRegExPattern
        oRegularExpression.IgnoreCase = True
        
        ' Validate virtual directory name
        If oRegularExpression.Test(sSegment) Then
            ' Port is either not an integer or not in a valid range
            ShowErrorMessage "The virtual directory segment contain the following characters: \, /, "", |, <, >, :, *, ?, ], [, +, =, ;, ,, @, &."
            Exit Function
        End If
    Next
     
    ' validate virtual directory existance
    Dim oIIS, oSite
    Set oIIS = GetObject("IIS://localhost/W3SVC")
    
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve IIS Websites - Please verify that the IIS is running!"
        Exit Function
    End If

    ' iterate through the sites
    For Each oSite In oIIS
        ' if the description is the same as the specified description, get the details
        If StrComp(oSite.Class, "IIsWebServer", vbTextCompare) = 0 Then
            If StrComp(oSite.ServerComment, sWebSiteName, vbTextCompare) = 0 Then
                Dim sVirtualDir, oVDir
                sVirtualDir = sVirtualDirName
                If (Right(sVirtualDir, 1) = "/") Then sVirtualDir = Left(sVirtualDir, Len(sVirtualDir) - 1)
                If (Left(sVirtualDir, 1) <> "/") Then sVirtualDir = "/" + sVirtualDir
                If (Left(sVirtualDir, 5) <> "/ROOT") Then sVirtualDir = "/ROOT" + sVirtualDir
                
                Err.Clear
                Set oVDir = GetObject(oSite.AdsPath & sVirtualDir)
                If Err.Number = 0 Then
                    If StrComp(oVDir.Class, "IIsWebVirtualDir", vbTextCompare) = 0 Then
                        ShowErrorMessage "Virtual directory already exists - Please choose another virtual directory for setup!"
                        Exit Function
                    End If
                End If
            End If
        End If
    Next
    Set oIIS = Nothing
        
    Session.Property("IIS_CHECKVIRTUALDIR") = "1"
End Function

'===========================================================================
' This function validate appplication pool name
'===========================================================================
Public Function CheckApplicationPoolName()
    Dim oRegularExpression, sApplicationPoolName, iMaxCharacters, sRegExPattern
    
    On Error Resume Next
    
    ' Set Defaults
    iMaxCharacters = 64
    
    ' Get Msi Installer properties
    sApplicationPoolName = Session.Property("IIS_NEWAPPPOOL")

    ' Set default result
    Session.Property("IIS_CHECKAPPPOOL") = "0"
    CheckApplicationPoolName = ERROR_SUCCESS
    
    If Len(sApplicationPoolName) < 1 Or Len(sApplicationPoolName) > iMaxCharacters Then
        ' Port is either not an integer or not in a valid range
        ShowErrorMessage "The application pool name lenght must be from 1 to " + CStr(iMaxCharacters) + "."
        Exit Function
    End If

    ' Set regex params
    sRegExPattern = "[\\\/\""\|\<\>\:\*\?\[\]\+\=\;\,\@\&]"
    
    ' Prepare regex for virtural directory name
    Set oRegularExpression = CreateObject("vbscript.regexp") 'New RegExp
    oRegularExpression.Pattern = sRegExPattern
    oRegularExpression.IgnoreCase = True
    
    ' Validate virtual directory name
    If oRegularExpression.Test(sApplicationPoolName) Then
        ' Port is either not an integer or not in a valid range
        ShowErrorMessage "The application pool name cannot contain the following characters: \, /, "", |, <, >, :, *, ?, ], [, +, =, ;, ,, @, &."
        Exit Function
    End If
     
    Session.Property("IIS_CHECKAPPPOOL") = "1"
End Function

'===========================================================================
' This function set appplication pool name
'===========================================================================
Public Function SetApplicationPoolName()
    Dim sVirtualDir, sAppPoolName, lPos
    
    On Error Resume Next

    ' Get Msi Installer properties
    sVirtualDir = Session.Property("IIS_VIRTUALDIR")
    sVirtualDir = Replace(sVirtualDir, "/", "\")

    lPos = InStr(1, sVirtualDir, "\", vbTextCompare)
    If lPos > 0 Then
        sAppPoolName = Left(sVirtualDir, lPos - 1)
    Else
        sAppPoolName = Left(sVirtualDir, 64) ' No more 64
    End If
       
    Session.Property("IIS_NEWAPPPOOL") = sAppPoolName
End Function

'===========================================================================
' This function populates the MSI properties of the specified website
'===========================================================================
Public Function PopulateWebSiteProperties()
    Dim oIIS, oSite
    
    On Error Resume Next
    
    ' Set Default
    PopulateWebSiteProperties = ERROR_INSTALL_FAILURE
    'If VBA Then
    '    MsgBox "IIS_WEBSITE:" + Session.Property("IIS_WEBSITE") & vbCrLf & _
    '           "IIS_VIRTUALDIR:" + Session.Property("IIS_VIRTUALDIR")
    'Endif

    ' instanciate the IIS object
    Set oIIS = GetObject("IIS://localhost/W3SVC")
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve IIS Websites - Please verify that the IIS is running!"
        Exit Function
    End If

    ' iterate through the sites
    For Each oSite In oIIS
        ' if the description is the same as the specified description, get the details
        If StrComp(oSite.Class, "IIsWebServer", vbTextCompare) = 0 Then

            If StrComp(oSite.ServerComment, Session.Property("IIS_WEBSITE"), vbTextCompare) = 0 Then

                'get the site path
                Dim oRoot, sPhysicalDir, sVirtualDir, sDirName, bNoSetInstallDir
                sVirtualDir = Session.Property("IIS_VIRTUALDIR")
                sVirtualDir = Replace(sVirtualDir, "/", "\")
                If (Right(sVirtualDir, 1) = "\") Then sVirtualDir = Left(sVirtualDir, Len(sVirtualDir) - 1)
                If (Left(sVirtualDir, 1) <> "\") Then sVirtualDir = "\" + sVirtualDir

                Set oRoot = GetObject(oSite.AdsPath & "/Root")
                
                If (Err.Number <> 0) Then
                    ShowErrorMessage "Unable to retrieve IIS Website Root directory - Please verify that the IIS is running!"
                    Exit Function
                End If
                
                bNoSetInstallDir = Session.Property("IIS_NOSETINSTALLDIR")
                If (Not bNoSetInstallDir = "1") Then
                    sDirName = Session.Property("IIS_INSTALLDIR")
                    If Len(sDirName) > 0 Then
                        Session.Property(sDirName) = oRoot.Path & sVirtualDir
                    End If
                    'MsgBox "IIS_INSTALLDIR:" & Session.Property("IIS_INSTALLDIR")
                End If
                            
                'get the properties of the site
                Dim strServerBinding, BindingArray
                For Each strServerBinding In oSite.ServerBindings
                    BindingArray = Split(strServerBinding, ":", -1, 1)

                    If Len(BindingArray(0)) = 0 Then BindingArray(0) = "*"
                    Session.Property("IIS_IPADDRESS") = BindingArray(0)
                    Session.Property("IIS_TARGETWEBPORT") = BindingArray(1)
                    Session.Property("IIS_HEADER") = BindingArray(2)
            
                    Exit For
                Next
                
                PopulateWebSiteProperties = ERROR_SUCCESS
                Exit For
            End If
        End If
    Next
    
    'clean up
    Set oSite = Nothing
    Set oIIS = Nothing
End Function

'===========================================================================
' This function evaluate the MSI properties of the specified website
'===========================================================================
Public Function EvaluateWebSiteProperties()
    Dim oIIS, oSite
    
    'On Error Resume Next
    
    ' Set Default
    EvaluateWebSiteProperties = ERROR_INSTALL_FAILURE
    'MsgBox "TARGETDIR:" + Session.Property("TARGETDIR")

    ' instanciate the IIS object
    Set oIIS = GetObject("IIS://localhost/W3SVC")
    
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve IIS Websites - Please verify that the IIS is running!"
        Exit Function
    End If
    
    ' iterate through the sites
    For Each oSite In oIIS
        ' if the description is the same as the specified description, get the details
        If StrComp(oSite.Class, "IIsWebServer", vbTextCompare) = 0 Then
            'get the Virtual Dir
            Dim sPhysicalDir, sVirtualDir, sVirtualDirAdsPath, sDirName, oVirDir
            sDirName = Session.Property("IIS_INSTALLDIR")
            If (Len(sDirName) = 0) Then
                sDirName = "TARGETDIR"
            End If

            sPhysicalDir = Session.Property(sDirName)
            If (Right(sPhysicalDir, 1) = "\") Then sPhysicalDir = Left(sPhysicalDir, Len(sPhysicalDir) - 1)
            
            Set oVirDir = EnumVirtualDirectories(oSite, sPhysicalDir)
            If Not oVirDir Is Nothing Then
                Session.Property("IIS_WEBSITE") = oSite.ServerComment

                sVirtualDirAdsPath = oVirDir.AdsPath
                sVirtualDir = Right(sVirtualDirAdsPath, Len(sVirtualDirAdsPath) - Len(oSite.AdsPath & "/ROOT") - 1)
                Session.Property("IIS_VIRTUALDIR") = sVirtualDir
              
                'get the properties of the site
                Dim strServerBinding, BindingArray
                For Each strServerBinding In oSite.ServerBindings
                    BindingArray = Split(strServerBinding, ":", -1, 1)
                    
                    If Len(BindingArray(0)) = 0 Then BindingArray(0) = "*"
                    Session.Property("IIS_IPADDRESS") = BindingArray(0)
                    Session.Property("IIS_TARGETWEBPORT") = BindingArray(1)
                    Session.Property("IIS_HEADER") = BindingArray(2)

                    Exit For
                Next
                
                Session.Property("IIS_NEWAPPPOOL") = oVirDir.AppPoolID
                
                'MsgBox "IIS_WEBSITE:" + Session.Property("IIS_WEBSITE") & vbCrLf & _
                '"IIS_VIRTUALDIR:" + Session.Property("IIS_VIRTUALDIR") & vbCrLf & _
                '"IIS_IPADDRESS:" + Session.Property("IIS_IPADDRESS") & vbCrLf & _
                '"IIS_TARGETWEBPORT:" + Session.Property("IIS_TARGETWEBPORT") & vbCrLf & _
                '"IIS_HEADER:" + Session.Property("IIS_HEADER")
                
                EvaluateWebSiteProperties = ERROR_SUCCESS
                Exit For
            End If
        End If
    Next
    
    ' skip SKIPCONFIGUREIIS if error
    If EvaluateWebSiteProperties <> ERROR_SUCCESS Then
        Session.Property("SKIPCONFIGUREIIS") = "1"
        EvaluateWebSiteProperties = ERROR_SUCCESS
    End If
    
    'clean up
    Set oSite = Nothing
    Set oIIS = Nothing
End Function

Private Function EnumVirtualDirectories(oIIsObject, sVDir)
    Dim oVirDir, oObject
    Set oVirDir = Nothing

    For Each oObject In oIIsObject
        If StrComp(oObject.Class, "IIsWebVirtualDir", vbTextCompare) = 0 Then
            If (StrComp(oObject.Path, sVDir, vbTextCompare) = 0) Then
                Set oVirDir = oObject
                Exit For
            End If
            
            Set oVirDir = EnumVirtualDirectories(oObject, sVDir)
            If Not oVirDir Is Nothing Then
                Exit For
            End If
        End If
        
        If StrComp(oObject.Class, "IIsWebDirectory", vbTextCompare) = 0 Then
            Set oVirDir = EnumVirtualDirectories(oObject, sVDir)
            If Not oVirDir Is Nothing Then
                Exit For
            End If
        End If
    Next
    
    Set EnumVirtualDirectories = oVirDir
End Function

'===========================================================================
' This function return application pools list
'===========================================================================
Public Function ListAppPools()
    Dim oIISAppPools, oAppPool, iInt, fDefault, strAppPoolName
    
    On Error Resume Next
    
    ' Set Default
    ListAppPools = ERROR_INSTALL_FAILURE
    
    ' instanciate the IIS AppPools object
    Set oIISAppPools = GetObject("IIS://localhost/W3SVC/AppPools")
    
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve IIS Applicatin Pools - Please verify that the IIS is running!"
        Exit Function
    End If
    
    ' iterate through the AppPools
    iInt = 1
    For Each oAppPool In oIISAppPools
        strAppPoolName = oAppPool.Name
        ' Add to combo box
        Call AddToComboBox("IIS_APPPOOL", iInt, strAppPoolName, strAppPoolName)
        ' Found into App pool list deafult AppPool value
        If Session.Property("IIS_APPPOOL") = strAppPoolName Then fDefault = True
        
        iInt = iInt + 1
    Next
    
    ' if default value not found, then set last valid value
    If fDefault = False Then Session.Property("IIS_APPPOOL") = strAppPoolName
    
    'clean up
    Set oIISAppPools = Nothing
    
    ListAppPools = ERROR_SUCCESS
End Function

'===========================================================================
' Get websites currently configured in IIS and adds them to a drop down box
'===========================================================================
Public Function ListWebSites()
    Dim oIIS, oSite, iInt, fDefault, sServerComment
    
    On Error Resume Next
    
    ' Set Default
    ListWebSites = ERROR_INSTALL_FAILURE
    
    ' instanciate the IIS object
    Set oIIS = GetObject("IIS://localhost/W3SVC")
    
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve IIS Websites - Please verify that the IIS is running!"
        Exit Function
    End If
    
    ' iterate through the sites
    iInt = 1
    For Each oSite In oIIS
        If StrComp(oSite.Class, "IIsWebServer", vbTextCompare) = 0 Then
            sServerComment = oSite.ServerComment
            ' Add to combo box
            Call AddToComboBox("IIS_WEBSITE", iInt, sServerComment, sServerComment)
            ' Found into Web site list deafult Web site value
            If Session.Property("IIS_WEBSITE") = sServerComment Then fDefault = True
            iInt = iInt + 1
        End If
    Next
    
    ' if default value not found, then set last valid value
    If fDefault = False Then Session.Property("IIS_WEBSITE") = sServerComment
    
    'clean up
    Set oIIS = Nothing
    
    ListWebSites = ERROR_SUCCESS
End Function


Private Sub AddToComboBox(ByVal ComboProp, ByVal ComboOrder, ByVal ComboValue, ByVal ComboText)
 
    ' This function takes values passed into it from the function call and uses these values to create
    ' and execute a view within the current session of the Windows Installer object.  This view is based
    ' on a SQL query constructed using the values passed into the function. If you wish to get a deeper
    ' understanding of how this function works you should read up on the Windows Installer object
    ' model in the Windows Installer SDK.
     
    ' Initialize variables
    Dim query
    Dim view
     
    ' Construct query based on values passed into the function.
    ' NOTE:  The ` character used is not a single quote, but rather a back quote.  This character is typically
    ' found on the key used for the ~ symbol in the upper left of the keyboard.
     
    query = "INSERT INTO `ComboBox` (`Property`, `Order`, `Value`, `Text`) VALUES ('" & ComboProp & "', " & ComboOrder & ", '" & ComboValue & "', '" & ComboText & "') TEMPORARY"

''********************** DEBUG **********************
'    If VBA Then
'        Debug.Print query
'        Exit Sub
'    End If
''********************** DEBUG **********************

    ' This statement creates the view object based on our query
    Set view = Session.DataBase.OpenView(query)
     
    ' This statement executes the view, which actually adds the row into the ComboBox table.
    view.Execute
    view.Close
 End Sub


