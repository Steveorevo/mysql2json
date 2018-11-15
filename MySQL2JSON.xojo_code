#tag Class
Protected Class MySQL2JSON
	#tag Method, Flags = &h0
		Sub ConnectToDB()
		  db = New MySQLCommunityServer
		  If sHost = "localhost" Then
		    db.Host = "127.0.0.1" // local resolution bug
		  Else
		    db.Host = sHost
		  End If
		  db.Port = nPort
		  db.DatabaseName = sDatabase
		  db.UserName = sUser
		  db.Password = sPassword
		  db.TimeOut = 60
		  If Not db.Connect Then
		    
		    // Connection error
		    Print db.ErrorMessage
		    Quit(1)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetNamedArg(sName As String, sDefault As String) As String
		  // Return parsed value of default if not found
		  If sArgs.InStr("--" + sName + "=") > 0 Then
		    Return sArgs.DelLeftMost("--" + sName + "=").GetLeftMost(" ")
		  Else
		    Return sDefault
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Initialize(args() as String)
		  // Init CRLF
		  sCRLF = Chr(13) + Chr(10)
		  
		  // Print hint
		  If UBound(args) < 1 Then
		    PrintHint
		  End If
		  
		  // Print help 
		  If args(1).InStr("--help") > 0 Or args(1).InStr("-?") > 0 Then
		    PrintHelp
		  End If
		  
		  // Parse arguments
		  For i As Integer = 1 to UBound(args)
		    sArgs = sArgs + args(i) + " "
		  Next i
		  sArgs = sArgs.ReplaceAll("-u ", "--user=")_
		  .ReplaceAll("-p ", "--password=")_
		  .ReplaceAll("-o ", "--output=")_
		  .ReplaceAll("-t ", "--tables=")_
		  .ReplaceAll("-h ", "--host=")_
		  .ReplaceAll("-P ", "--port=")_
		  .ReplaceAll("-l ", "--list ")_
		  .ReplaceAll("-q ", "--quiet ")_
		  .ReplaceAll("-v ", "--version ")
		  bList = sArgs.InStr("--list") > 0
		  bQuiet = sArgs.InStr("--quiet") > 0
		  nPort = Val(GetNamedArg("port", "3306"))
		  sDatabase = sArgs.Trim.GetRightMost(" ")
		  sHost = GetNamedArg("host", "localhost")
		  sPassword = GetNamedArg("password", "")
		  sUser = GetNamedArg("user", "root")
		  sOutput = GetNamedArg("output", "")
		  sTables = GetNamedArg("tables", "")
		  If sArgs.InStr("--version ") > 0 Then
		    Print "MySQL2JSON version " +_
		    App.MajorVersion.ToText + "." +_
		    App.MinorVersion.ToText + "." +_
		    App.BugVersion.ToText +_
		    " (build " + App.NonReleaseVersion.ToText + ")"
		    Print App.Description
		    Print App.Copyright
		    Quit
		  End If
		  If sOutput = "" Then
		    sOutput = "./" + sDatabase + ".json"
		  End If
		  
		  // Show available databases or tables
		  Dim rs As RecordSet
		  If bList Then
		    Dim sHoldDB As String = sDatabase
		    sDatabase = "mysql"
		    ConnectToDB
		    Dim sDBList As String
		    rs = db.SQLSelect("SHOW DATABASES")
		    While Not rs.EOF
		      sDBList.Append("   " + rs.Field("Database").StringValue + sCRLF)
		      rs.MoveNext
		    Wend
		    rs.Close
		    If sHoldDB = "--list" Then
		      
		      // List available db and exit
		      Print "Available databases:"
		      Print sDBList
		    Else
		      
		      // List available tables
		      If sDBList.InStr(" " + sHoldDB + sCRLF) = 0 Then
		        Print "Unknown database: " + sHoldDB
		      Else
		        // Reconnect to specifid db
		        db.Close
		        sDatabase = sHoldDB
		        ConnectToDB
		        rs = db.SQLSelect("SHOW TABLES")
		        Print "Available tables in " + sDatabase + ":"
		        While Not rs.EOF
		          Print "   " + rs.Field("Tables_in_" + sDatabase).StringValue
		          rs.MoveNext
		        Wend
		        Print ""
		        rs.Close
		      End If
		    End If
		    db.Close
		    Quit
		  End If
		  
		  // Connect to database
		  ConnectToDB
		  
		  // Build JSON Object, define database and table creation
		  jsonDB = New JSONItem
		  jsonDB.Compact = False
		  jsonDB.Value("name") = sDatabase
		  rs = db.SQLSelect("SHOW CREATE DATABASE " + sDatabase)
		  If rs <> Nil Then
		    jsonDB.Value("create") = rs.Field("Create Database").StringValue
		  End If
		  rs.Close
		  rs = db.SQLSelect("SHOW TABLES")
		  jsonDB.Value("tables") = New JSONItem
		  sTables.Append(",")
		  If rs <> Nil Then
		    While Not rs.EOF
		      If sTables = "," Or sTables.InStr(rs.Field("Tables_in_" + sDatabase).StringValue + ",") > 0 Then
		        Dim jsonTable As New JSONItem
		        jsonTable.Value("name") = rs.Field("Tables_in_" + sDatabase).StringValue
		        jsonDB.Child("tables").Append(jsonTable)
		        jsonTable = Nil
		      End If
		      rs.MoveNext
		    Wend
		  End If
		  rs.Close
		  For n As Integer = 0 to jsonDB.Child("tables").Count - 1
		    rs = db.SQLSelect("SHOW CREATE TABLE " + jsonDB.Child("tables").Child(n).Value("name"))
		    If rs <> Nil Then
		      jsonDB.Child("tables").Child(n).Value("create") = rs.Field("Create Table").StringValue
		    End If
		    rs.Close
		  Next n
		  
		  // Dump data for given table
		  For n As Integer = 0 to jsonDB.Child("tables").Count - 1
		    If Not bQuiet Then
		      Print Chr(8) + "Dumping " + jsonDB.Child("tables").Child(n).Value("name").StringValue
		    End If
		    rs = db.SQLSelect("SELECT * FROM " + jsonDB.Child("tables").Child(n).Value("name").StringValue)
		    jsonDB.Child("tables").Child(n).Value("columns") = New JSONItem
		    jsonDB.Child("tables").Child(n).Value("data") = New JSONItem("[]")
		    
		    // Record columns, type
		    For i As Integer = 1 to rs.FieldCount
		      Dim jsonCol As New JSONItem
		      jsonCol.Value("name") = rs.IdxField(i).Name
		      Dim sMySQLBaseType As String = jsonDB.Child("tables").Child(n).Value("create")
		      sMySQLBaseType = sMySQLBaseType.DelLeftMost("`" + rs.IdxField(i).Name + "` ").GetLeftMost(" ").GetLeftMost("(")
		      Dim sJSONType As String
		      Select Case sMySQLBaseType
		      Case "char","varchar","tinytext","text","mediumtext","longtext","binary","varbinary","date","datetime","timestamp","time","year"
		        sJSONType = "string"
		      Case "bit","tinyint","smallint","mediumint","int","integer","bigint","decimal","dec","fixed","float","double","real"
		        sJSONType = "number"
		      Case "bool", "boolean"
		        sJSONType = "boolean"
		      End Select
		      jsonCol.Value("json_type") = sJSONType
		      jsonCol.Value("mysql_type") = sMySQLBaseType
		      jsonDB.Child("tables").Child(n).Child("columns").Append(jsonCol)
		      jsonCol = Nil
		    Next i
		    
		    // Dump data
		    If rs <> Nil Then
		      While Not rs.EOF
		        Dim jsonData As New JSONItem
		        For i As Integer = 1 to rs.FieldCount
		          Dim sJSONType As String = jsonDB.Child("tables").Child(n).Child("columns").Child(i-1).Value("json_type")
		          Dim sMySQLBaseType As String = jsonDB.Child("tables").Child(n).Child("columns").Child(i-1).Value("mysql_type")
		          
		          // Detect PHP serialization and convert to JSON object
		          If sJSONType = "string" Then
		            Dim sValue As String = rs.Field(rs.IdxField(i).Name).StringValue
		            
		            // Detect UTF8/ASCII encoding issues
		            Dim sTest As String = DefineEncoding(sValue, Encodings.UTF8)
		            sValue = DefineEncoding(sValue, Encodings.ASCII)
		            If sTest.Len <> sTest.LenB Then
		              Dim bs As New BinaryStream(sValue)
		              Dim sNew As String
		              For b As Integer = 0 to bs.Length
		                Dim sChar As String
		                sChar = bs.Read(1, Encodings.ASCII)
		                If Asc(sChar) > 127 Then
		                  sNew.Append("\x" + Hex(Asc(sChar)))
		                Else
		                  sNew.Append(sChar)
		                End If
		              Next b
		              sValue = sNew
		            End If
		            Dim sID As String = sValue.Left(2)
		            Dim sC As String = "adObis"
		            If sID = "N;" Or (sID.Right(1) = ":" And sC.InStrB(sID.Left(1)) > 0) Then
		              jsonData.Value(rs.IdxField(i).Name) = PHPSerializeToJSON(sValue)
		            Else
		              jsonData.Value(rs.IdxField(i).Name) = sValue
		            End If
		          Else
		            If sJSONType = "number" Then
		              Dim sTypes As String = "decimal,dec,fixed,float,double,real,"
		              If sTypes.InStr(sMySQLBaseType + ",") > 0 Then
		                jsonData.Value(rs.IdxField(i).Name) = rs.Field(rs.IdxField(i).Name).DoubleValue
		              Else
		                jsonData.Value(rs.IdxField(i).Name) = rs.Field(rs.IdxField(i).Name).Int64Value
		              End If
		            Else
		              jsonData.Value(rs.IdxField(i).Name) = rs.Field(rs.IdxField(i).Name).BooleanValue
		            End If
		          End If
		        Next i
		        jsonDB.Child("tables").Child(n).Child("data").Append(jsonData)
		        jsonData = Nil
		        rs.MoveNext
		      Wend
		    End If
		    rs.Close
		  Next n
		  db.Close
		  
		  // Write to the output file
		  Dim fiOutput As FolderItem = GetFolderItem(sOutput, FolderItem.PathTypeNative)
		  If Not bQuiet Then
		    Print Chr(8) + "Please wait; writing output file at: " + fiOutput.NativePath
		  End If
		  WriteFile fiOutput, jsonDB.ToString 
		  If Not bQuiet Then
		    Print "Export complete."
		  End If
		  Quit
		  
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function PHPSerializeToJSON(sValue As String) As JSONItem
		  // Convert the given string containing PHP serialized data to a JSONItem
		  Dim fi As FolderItem = SpecialFolder.Temporary.Child("PHPSerializeToJSON.php")
		  Dim sCode As String = "<?php" + sCRLF
		  Dim sSpin() As String = Array(Chr(8)+"\",Chr(8)+"|",Chr(8)+"/",Chr(8)+"-")
		  Static nSpin As Integer
		  
		  // Encode double quotes, sCRLF, $
		  sValue = sValue.ReplaceAll(Chr(34), "\x22").ReplaceAll(Chr(13), "\x0D").ReplaceAll(Chr(10), "\x0A").ReplaceAll("$", "\x24")
		  sCode.Append(mb_unserialize)
		  sCode.Append("echo json_encode(mb_unserialize(utf8_encode(" + Chr(34) + sValue + Chr(34) + ")));")
		  WriteFile fi, sCode
		  
		  // Execute the file
		  Dim sh As New Shell
		  sh.Execute "php -f " + Chr(34) + fi.NativePath + Chr(34)
		  Dim sResult As String = sh.Result
		  sh.Close
		  If sResult = "false" Then
		    Dim x As Integer = 0
		  End If
		  Dim jsonResult As New JSONItem(sResult)
		  fi.Delete
		  If Not bQuiet Then
		    If nSpin > 3 Then nSpin = 0
		    StdOut.Write sSpin(nSpin)
		    nSpin = nSpin + 1
		  End If
		  Return jsonResult
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub PrintHelp()
		  Dim sVersion As String = App.MajorVersion.ToText + "." +_
		  App.MinorVersion.ToText + "." +_
		  App.BugVersion.ToText
		  Print "mysql2json v" + sVersion + " exports a given database to a JSON file with PHP serialization conversion."
		  Print "Usage: mysql2json [OPTION]... [DATABASE]"
		  Print ""
		  Print "Example: "
		  Print ""
		  Print "  mysql2json -u root -p exampleDB123"
		  Print ""
		  Print "or"
		  Print ""
		  Print "  mysql2json --user=root exampleDB123"
		  Print ""
		  Print "Connects to MySQL database on port 3306 with root credentials"
		  Print "and no password followed by dumping the database to a JSON file"
		  Print "of the same name containing all tables, creation definition and any"
		  Print "PHP serialized strings to child objects in 'pretty print' for"
		  Print "line-by-line analysis. The database name should be the last"
		  Print "argument parameter."
		  Print ""
		  Print "Startup:"
		  Print "  -?, --help           print this help"
		  Print "  -h, --host           host name or IP address (default: localhost)"
		  Print "  -l, --list           list databases & tables available for export"
		  Print "  -o, --output         path & file (default is db name in current folder)"
		  Print "  -p, --password       password to connect with (default is none)"
		  Print "  -P, --port           the TCP/IP port number to connect on"
		  Print "  -t, --tables         a comma delimited list of tables (default empty for all)"
		  Print "  -u, --user           username to connect as (default: root)"
		  Print "  -q, --quiet          quiet (no output)"
		  Print "  -v, --version        output version number"
		  Print ""
		  Quit
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub PrintHint()
		  Print "mysql2json: missing database name"
		  Print "Usage: mysql2json [OPTION]... [DATABASE]..."
		  Print ""
		  Print "Try 'mysql2json --help' for more options."
		  Quit
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ReadFile(fi As FolderItem) As String
		  // Simply reads the data from the given file in fi
		  // and returns it's content as a string
		  Using Xojo.Core
		  Using Xojo.IO
		  Dim xfi As New Xojo.IO.FolderItem(fi.NativePath.ToText)
		  Dim sData As String
		  Try
		    Dim tis As TextInputStream
		    tis = TextInputStream.Open(xfi, TextEncoding.ASCII)
		    sData = tis.ReadAll
		    tis.Close
		  Catch e As IOException
		    Print "File IO Error: " + e.Reason
		  End Try
		  Return sData
		  
		  'Dim sData As String
		  'Try
		  'Dim tis As TextInputStream
		  'tis = TextInputStream.Open(fi)
		  'sData = tis.ReadAll
		  'tis.Close
		  'Catch e As IOException
		  'Print "File IO Error: " + e.Reason
		  'End Try
		  'Return sData
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub WriteFile(fi As FolderItem, sData As String)
		  // Simply writes the data to the given file in fi
		  // If the file exists, overwrite it
		  'Using Xojo.Core
		  'Using Xojo.IO
		  'Dim xfi As New Xojo.IO.FolderItem(fi.NativePath.ToText)
		  'Try
		  'Dim tos As TextOutputStream = TextOutputStream.Create(xfi, TextEncoding.UTF8)
		  'tos.Write(sData.ToText)
		  'tos.Close
		  'Catch e As RuntimeException
		  'Print e.Message
		  'End Try
		  
		  Try
		    Dim tos As TextOutputStream = TextOutputStream.Create(fi)
		    tos.Write(sData)
		    tos.Close
		  Catch e As RuntimeException
		    Print e.Message
		  End Try
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		bList As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		bQuiet As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h0
		db As MySQLCommunityServer
	#tag EndProperty

	#tag Property, Flags = &h0
		jsonDB As JSONItem
	#tag EndProperty

	#tag Property, Flags = &h0
		nPort As Integer = 3306
	#tag EndProperty

	#tag Property, Flags = &h0
		sArgs As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sCRLF As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sDatabase As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sHost As String = "localhost"
	#tag EndProperty

	#tag Property, Flags = &h0
		sOutput As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sPassword As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sTables As String
	#tag EndProperty

	#tag Property, Flags = &h0
		sUser As String = "root"
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="bQuiet"
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="nPort"
			Group="Behavior"
			InitialValue="3306"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sArgs"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sCRLF"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sDatabase"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sHost"
			Group="Behavior"
			InitialValue="localhost"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sOutput"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sPassword"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sUser"
			Group="Behavior"
			InitialValue="root"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="bList"
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="sTables"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
