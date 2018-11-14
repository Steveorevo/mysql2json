#tag Module
Protected Module Extends_String
	#tag Method, Flags = &h0
		Function AddLastSlash(Extends sInput As String) As String
		  // Depending on the user platform, add the appropiate last slash
		  // if it isn't there already.
		  sInput = sInput.StripLastSlash
		  #If TargetMacOS
		    sInput.Append("/")
		  #Else
		    sInput.Append("\")
		  #Endif
		  Return sInput
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Append(Extends ByRef sInput As String, sStuff As String)
		  // Append additional string content to ourself
		  sInput = sInput + sStuff
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function CountString(Extends sSubject As String, sSearch As String) As Integer
		  // Return the number of occurances of sSearch in sSubject
		  Dim nCount As Integer
		  While InStr(sSubject, sSearch) > 0
		    sSubject = sSubject.DelLeftMost(sSearch)
		    nCount = nCount + 1
		  Wend
		  Return nCount
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function DelLeftMost(Extends sInput As String, sFind As String) As String
		  Dim n As Integer
		  n = sInput.InStr(sFind)
		  if (n > 0) then
		    return sInput.Right(Len(sInput) - n - Len(sFind) + 1)
		  else
		    return sInput
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function DelRightMost(Extends sInput As String, sFind As String) As String
		  Dim n As Integer
		  n = sInput.InStrRev(sFind)
		  if (n > 0) then
		    Return sInput.Left(n-1)
		  else
		    Return sInput
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetLeftMost(Extends sInput As String, sFind As String) As String
		  Dim n As Integer
		  n = sInput.InStr(sFind)
		  if (n > 0) Then
		    return sInput.Left(n -1)
		  else
		    If sInput = sFind Then
		      return ""
		    Else
		      return sInput
		    End If
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetRightMost(Extends sInput As String, sFind As String) As String
		  Dim n As Integer
		  n = sInput.InStrRev(sFind)
		  if (n > 0) then
		    return sInput.Right(Len(sInput) - (n + Len(sFind) -1))
		  else
		    return sInput
		  end if
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function InStrRev(Extends source As String, startPos As Integer=-1, substr As String) As Integer
		  // Similar to InStr, but searches backwards from the given position
		  // (or if startPos = -1, then from the end of the string).
		  // If substr can't be found, returns 0.
		  Dim srcLen As Integer = source.Len
		  if startPos = -1 then startPos = srcLen
		  
		  // Here's an easy way...
		  // There may be a faster implementation, but then again, there may not -- it probably
		  // depends on the particulars of the data.
		  Dim reversedSource As String = source.Reverse()
		  Dim reversedSubstr As String = substr.Reverse()
		  Dim reversedPos As Integer
		  reversedPos = InStr( srcLen - startPos + 1, reversedSource, reversedSubstr )
		  if reversedPos < 1 then return 0
		  return srcLen - reversedPos - substr.Len + 2
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Quoted(Extends source As String) As String
		  // Return the string as quoted (surrounded by ASCII 34)
		  Return Chr(34) + source + Chr(34)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Reverse(Extends s As String) As String
		  // Return s with the characters in reverse order.
		  
		  if Len(s) < 2 then return s
		  
		  Dim characters() as String = Split( s, "" )
		  Dim leftIndex as Integer = 0
		  Dim rightIndex as Integer = UBound(characters)
		  #pragma BackgroundTasks False
		  While leftIndex < rightIndex
		    Dim temp as String = characters(leftIndex)
		    characters(leftIndex) = characters(rightIndex)
		    characters(rightIndex) = temp
		    leftIndex = leftIndex + 1
		    rightIndex = rightIndex - 1
		  Wend
		  Return Join( characters, "" )
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function StripLastSlash(Extends sInput As String) As String
		  If Right(sInput, 1) = "/" Or Right(sInput, 1) = "\" Then
		    sInput = Left(sInput, Len(sInput) -1)
		  End If
		  Return sInput
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function StripTags(Extends sInput As String) As String
		  // Removes markup tags <something> </else>
		  Dim sParse As String
		  If Not (sInput.InStr("<") > 0 And sInput.InStr(">") > 0) Then
		    Return sInput
		  Else
		    While sInput.InStr("<") > 0 And sInput.InStr(">") > 0
		      sParse = sParse + sInput.GetLeftMost("<")
		      sInput = sInput.DelLeftMost(">")
		    Wend
		    sParse = sParse + sInput
		    Return sParse
		  End If
		  
		End Function
	#tag EndMethod


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule
