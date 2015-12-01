Option Explicit

Const ERROR_SUCCESS = 0
Const ERROR_INSTALL_FAILURE = 1603
Const msiMessageTypeError = &H01000000 

' Global database object
Dim oDB

'===========================================================================
' Function return connection string
'===========================================================================
Private Function GetConnectionString()
   Dim sDBHost, sDBUsername, sDBPassword, sSecurity, sConnectionString

   ' Get Values from Windows Installer
   sDBHost = Session.Property("SQL_SERVER")
   sDBUsername = Session.Property("SQL_USERNAME")
   sDBPassword = Session.Property("SQL_PASSWORD")
   sSecurity = Session.Property("SQL_AUTHENTICATION")
   
    If sSecurity = "user" Then
        ' user auth / sql authentification
        sConnectionString = "Provider=SQLOLEDB.1;Password=" & sDBPassword & ";Persist Security Info=True;User ID=" & sDBUsername & "; Data Source=" & sDBHost
    Else
        ' integrated security
        sConnectionString = "Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;Data Source=" & sDBHost
    End If
   
   ' Return connection string
   GetConnectionString = sConnectionString
End Function

'===========================================================================
' Function show error message box
'===========================================================================
Private Sub ShowErrorMessage(ByVal message)
    If Err.Number <> 0 Then
        message = message & vbCrLf & _
         "Error Details: " & Err.Description & " [Number:" & Hex(Err.Number) & "]"
    End If
'    If Session.Property("UILevel") = "5" Then
'        MsgBox message, vbCritical, "Error"
'    End If
    Dim record    
    Set record = Session.Installer.CreateRecord(0)
    record.StringData(0) = message
    Session.Message msiMessageTypeError, record

End Sub

'===========================================================================
' Function Create database object
'===========================================================================
Private Function CreateDatabaseObject()
    Dim sConnectionString

    On Error Resume Next
        
    If oDB <> Empty Then
        CreateDatabaseObject = True
        Exit Function
    End If
        
    ' Get connection string
    sConnectionString = GetConnectionString()
        
    ' Crate ADODB Object
    Set oDB = CreateObject("ADODB.Connection")
      
    ' Check if object could be created
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to create ADODB Object - please verify that ASP.NET 2.0 is installed!"
        CreateDatabaseObject = False
        Exit Function
    End If
    
    ' Open connection
    oDB.Open (sConnectionString)
    
    ' Check if connection worked
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to connect to Database - please provide accurate login data!"
        CreateDatabaseObject = False
        Exit Function
    End If
    
    CreateDatabaseObject = True
End Function

'===========================================================================
' Check if a dabase login is possible and if the provided
' username is privileged enough to do a few things like:
' - create databases
' - create users
' - and if the database authentification mode is mixed
'===========================================================================
Public Function CheckDatabaseLogin()
    Dim sSQL, oResultSet

    On Error Resume Next

    ' Set Default
    Session.Property("SQL_CHECKDATABASELOGIN") = "0"
    'CheckDatabaseLogin = ERROR_INSTALL_FAILURE
    
    ' Create Database object
    If Not CreateDatabaseObject() Then
        Exit Function
    End If
        
    ' Check for create database privleges
    Dim sCreateDatabase
    sCreateDatabase = "no"
    
    sSQL = "IF PERMISSIONS() & 2 = 2 SELECT 'yes' AS createDatabase ELSE SELECT 'no' AS createDatabase"
    
    Set oResultSet = oDB.Execute(sSQL)
    
    Do While Not oResultSet.EOF
        sCreateDatabase = oResultSet("createDatabase")
        oResultSet.MoveNext
    Loop
    
    If sCreateDatabase = "no" Then
        ShowErrorMessage "The provided user account is invalid - it has insuffient rights to create a database!"
        Exit Function
    End If

'    ' Check for create user / login privileges
'    Dim sAddUserAndLogin
'    sAddUserAndLogin = "no"
'
'    sSQL = "IF (PERMISSIONS(OBJECT_ID('sp_adduser')) & 8 = 8) AND (PERMISSIONS(OBJECT_ID('sp_addlogin')) & 8 = 8)" & _
'            "SELECT 'yes' AS addUserAndLogin ELSE SELECT 'no'  AS addUserAndLogin"
'
'    Set oResultSet = oDB.Execute(sSQL)
'
'    Do While Not oResultSet.EOF
'        sAddUserAndLogin = oResultSet("addUserAndLogin")
'        oResultSet.MoveNext
'    Loop
'
'    If sAddUserAndLogin = "no" Then
'        MsgBox "The provided user account is invalid - it has insuffient rights to create a User and or Login!", vbCritical, "Error"
'        Exit Function
'    End If
'
'    ' Check for supported authentication methods
'    Dim sSecurityMode
'    sSecurityMode = "integrated"
'    sSQL = "IF serverproperty('IsIntegratedSecurityOnly') = 1 " & _
'           "   SELECT 'integrated' as securityMode " & _
'           "ELSE " & _
'           "   SELECT 'user' as securityMode"
'
'    Set oResultSet = oDB.Execute(sSQL)
'
'    Do While Not oResultSet.EOF
'        sSecurityMode = oResultSet("securityMode")
'        oResultSet.MoveNext
'    Loop
'
'    If sSecurityMode = "integrated" Then
'        MsgBox "This database server only supports integrated windows authentification - Please enable SQL Logins (See http://www.microsoft.com/technet/prodtechnol/sql/2005/mgsqlexpwssmse.mspx for further instructions)!", vbCritical, "Error"
'        Exit Function
'    End If

      ' Return values
      Session.Property("SQL_CHECKDATABASELOGIN") = "1"
      CheckDatabaseLogin = ERROR_SUCCESS
End Function

'===========================================================================
' This function return a SQL server databse version
'===========================================================================
Public Function GetDataBaseVersion()
    Dim sSQL, oResultSet, sDBVersion, sDBApplyVersion, sDBName

    On Error Resume Next

    ' Set Default
    GetDataBaseVersion = ERROR_INSTALL_FAILURE
    
    ' Get Values from Windows Installer
    sDBApplyVersion = Session.Property("SQL_APPLYDATABASEVERSION")
    sDBName = Session.Property("SQL_DATABASENAME")
    
    ' Create Database object
    If Not CreateDatabaseObject() Then
        Exit Function
    End If
    
    ' Get database version
    sSQL = "SELECT CAST(value AS varchar) AS version from [" & sDBName & "]..fn_listextendedproperty('DatabaseVersionNumber', null, null, null, null, null, null)"
    
    Set oResultSet = oDB.Execute(sSQL)
    
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to retrieve database version - Please choose another User for Database setup!"
        Exit Function
    End If
    
    Do While Not oResultSet.EOF
        sDBVersion = oResultSet("version")
        oResultSet.MoveNext
    Loop
    
    Session.Property("SQL_DATABASEVERSION") = sDBVersion
    
    If sDBVersion >= sDBApplyVersion Then
        ShowErrorMessage "Unable to apply update script v" & sDBApplyVersion & ": script already applied!"
        Exit Function
    End If
            
    ' Return result
    GetDataBaseVersion = ERROR_SUCCESS
End Function

'===========================================================================
' This function
'===========================================================================
Public Function CheckDatabaseName()
   Dim oRegularExpression, iReturn, sDatabaseName, iMinLength, iMaxLength, sSQL, oResultSet, bFound

    On Error Resume Next
    
    ' Set defaults
    iMinLength = 3
    iMaxLength = 32
    bFound = False
    
    ' Get sDatabaseName
    sDatabaseName = Session.Property("SQL_DATABASENAME")
    
    ' Set default result
    Session.Property("SQL_CHECKDATABASENAME") = "0"
    'CheckDatabaseName = ERROR_INSTALL_FAILURE
    
    ' Prepare regex validation for integer value
    Set oRegularExpression = CreateObject("vbscript.regexp") 'New RegExp
    oRegularExpression.Pattern = "^[\.a-z0-9A-Z\_]{" & iMinLength & "," & iMaxLength & "}$"
    oRegularExpression.IgnoreCase = True
    
    ' Validate if the database name machtes naming policy
    If Not oRegularExpression.Test(sDatabaseName) Then
        ' Port is either not an integer or not in a valid range
        ShowErrorMessage "The specified database name is invalid. The name has to be at least " & iMinLength & " Characters (Max: " & iMaxLength & ") allowed are A-Z, a-z, underscore and the Numbers from 0 to 9!"
        Exit Function
    End If
    
    ' Validate against database... (sql injection impossible because of regex)
    If Not CreateDatabaseObject() Then
        Exit Function
    End If
        
    sSQL = "SELECT name FROM master.dbo.sysdatabases WHERE name = '" & sDatabaseName & "'"

    Set oResultSet = oDB.Execute(sSQL)
     
    If (Err.Number <> 0) Then
        ShowErrorMessage "Unable to check if database already exists - Please choose another User for Database setup!"
        Exit Function
    End If
     
    Do While Not oResultSet.EOF
      bFound = True
      oResultSet.MoveNext
    Loop

    If bFound Then
        ShowErrorMessage "The specified database already exists please choose another name!"
        Exit Function
    End If
   
   CheckDatabaseName = ERROR_SUCCESS
   Session.Property("SQL_CHECKDATABASENAME") = "1"
End Function

'===========================================================================
' This function return a list of available Databses on SQL server
'===========================================================================
Public Function ListDataBaseNames()
    Dim sSQL, oResultSet, iInt, sDBName, sDBOriginalName, fDefault
    
    On Error Resume Next

    ' Set Default
    ListDataBaseNames = ERROR_INSTALL_FAILURE
    sDBOriginalName = Session.Property("SQL_DATABASEORIGINALNAME")
    
    ' Create Database object
    If Not CreateDatabaseObject() Then
        Exit Function
    End If
    
    ' Get Data Bases
    sSQL = "SELECT name FROM master.dbo.sysdatabases"
    
    Set oResultSet = oDB.Execute(sSQL)
    
    Call ClearComboBox("SQL_DATABASENAME")
    iInt = 0
    Do While Not oResultSet.EOF
        sDBName = oResultSet("name")
        
        If StrComp(GetDataBaseOriginalName(sDBName), sDBOriginalName, vbTextCompare) = 0 Then
            Call AddToComboBox("SQL_DATABASENAME", iInt, sDBName, sDBName)
            
            If Session.Property("SQL_DATABASENAME") = sDBName Then fDefault = True
            
            iInt = iInt + 1
        End If
        oResultSet.MoveNext
    Loop

    ' if default value not found, then set last valid value
    If fDefault = False Then Session.Property("SQL_DATABASENAME") = sDBName

    ' Return result
    ListDataBaseNames = ERROR_SUCCESS
End Function

Private Function GetDataBaseOriginalName(ByVal sDBName)
    Dim sSQL, oResultSet, sDBOriginalName
    
    On Error Resume Next
    
    ' Create Database object
    If Not CreateDatabaseObject() Then
        Exit Function
    End If
    
    ' Get database version
    sSQL = "SELECT CAST(value AS varchar) AS name from [" & sDBName & "]..fn_listextendedproperty('DatabaseOriginalName', null, null, null, null, null, null)"
    
    Set oResultSet = oDB.Execute(sSQL)
    
    If (Err.Number <> 0) Then
        'If it is insufficiently right to retrive database property
        'ShowErrorMessage "Unable to retrieve database original name - Please choose another User for Database setup!"
        Exit Function
    End If
    
    Do While Not oResultSet.EOF
        sDBOriginalName = oResultSet("name")
        oResultSet.MoveNext
    Loop
    
    GetDataBaseOriginalName = sDBOriginalName
End Function


'===========================================================================
' This function return a list of available SQL servers
'===========================================================================
Public Function ListSqlServers()

    ' Initialize variables
    Dim oDMOApp, oCollection, iInt, sSQLServer, fDefault

    ' Allow errors
    On Error Resume Next

    ' Get a list of available servers
    Set oDMOApp = CreateObject("SQLDMO.Application")
    
    If Err.Number <> 0 Then
        ShowErrorMessage "Unable to retrieve list available sql servers!"
        ListSqlServers = ERROR_INSTALL_FAILURE
    End If

    Set oCollection = oDMOApp.ListAvailableSQLServers

    ' Add the server names to ComboBox property
    For iInt = 1 To oCollection.Count
        sSQLServer = oCollection(iInt)
        
        Call AddToComboBox("SQL_SERVER", iInt + 1, sSQLServer, sSQLServer)
        
        If Session.Property("SQL_SERVER") = sSQLServer Then fDefault = True
    Next

    ' if default value not found, then set last valid value
    If fDefault = False Then Session.Property("SQL_SERVER") = sSQLServer
    
    ' Release objects
    Set oCollection = Nothing
    Set oDMOApp = Nothing

    ListSqlServers = ERROR_SUCCESS
End Function

'===========================================================================
' This function takes values passed into it from the function call and uses these values to create
' and execute a view within the current session of the Windows Installer object.  This view is based
' on a SQL query constructed using the values passed into the function. If you wish to get a deeper
' understanding of how this function works you should read up on the Windows Installer object
' model in the Windows Installer SDK.
'===========================================================================
Private Sub AddToComboBox(ByVal ComboProp, ByVal ComboOrder, ByVal ComboValue, ByVal ComboText)
 
    ' Initialize variables
    Dim sQuery
    Dim oView
     
    ' Construct query based on values passed into the function.
    ' NOTE:  The ` character used is not a single quote, but rather a back quote.  This character is typically
    ' found on the key used for the ~ symbol in the upper left of the keyboard.
    sQuery = "INSERT INTO `ComboBox` (`Property`, `Order`, `Value`, `Text`) VALUES ('" & ComboProp & "', " & ComboOrder & ", '" & ComboValue & "', '" & ComboText & "') TEMPORARY"

    ' This statement creates the view object based on our query
    Set oView = Session.DataBase.OpenView(sQuery)
     
    ' This statement executes the view, which actually adds the row into the ComboBox table.
    oView.Execute
    
    oView.Close
 End Sub

Private Sub ClearComboBox(ByVal ComboProp)
 
    ' Initialize variables
    Dim sQuery
    Dim oView
     
    ' Construct query based on values passed into the function.
    ' NOTE:  The ` character used is not a single quote, but rather a back quote.  This character is typically
    ' found on the key used for the ~ symbol in the upper left of the keyboard.
    sQuery = "DELETE FROM `ComboBox` WHERE `Property` = '" & ComboProp & "'"

    ' This statement creates the view object based on our query
    Set oView = Session.DataBase.OpenView(sQuery)
     
    ' This statement executes the view, which actually adds the row into the ComboBox table.
    oView.Execute
    
    oView.Close
 End Sub

