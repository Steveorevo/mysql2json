#tag Class
Protected Class App
Inherits ConsoleApplication
	#tag Event
		Function Run(args() as String) As Integer
		  mMySQL2JSON = New MySQL2JSON
		  mMySQL2JSON.Initialize(args)
		  
		End Function
	#tag EndEvent


	#tag Property, Flags = &h21
		Private mMySQL2JSON As MySQL2JSON
	#tag EndProperty


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
