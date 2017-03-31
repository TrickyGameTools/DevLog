Rem
	DevLog
	A simple DevLog tool for github.io sites
	
	
	
	(c) Jeroen P. Broks, 2016, 2017, All rights reserved
	
		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU General Public License as published by
		the Free Software Foundation, either version 3 of the License, or
		(at your option) any later version.
		
		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.
		You should have received a copy of the GNU General Public License
		along with this program.  If not, see <http://www.gnu.org/licenses/>.
		
	Exceptions to the standard GNU license are available with Jeroen's written permission given prior 
	to the project the exceptions are needed for.
Version: 17.01.04
End Rem
Strict

Rem

	Current version only yet set up for Mac.
	Some extra stuf may be done for a succeful Windows build.
	
End Rem	

Framework maxgui.drivers
Import    tricky_units.initfile2
Import    tricky_units.Dirry
Import    brl.maxlua
Import	  brl.eventqueue
Import    tricky_units.prefixsuffix

?win32
Import "devlog.o"
Const FPrefix$ = "WIN"
?MacOS
Const FPrefix$ = "MAC"
?Linux
Const  FPrefix$ = "LIN"
? 
' Originally meant as a prefix, but it became a suffix, but it was too much hassle to change that now. :-P

AppTitle = StripAll(AppFile)
?Debug
AppTitle:+" - DEBUG BUILD"
?

MKL_Version "DevLog - DevLog.bmx","17.01.04"
MKL_Lic     "DevLog - DevLog.bmx","GNU General Public License 3"

Global Win:TGadget = CreateWindow(StripDir(AppFile),0,0,ClientWidth(Desktop())*.95,ClientHeight(Desktop())*.95,Null,Window_titlebar | Window_center | Window_Menu)
Global WW = ClientWidth(win)
Global WH = ClientHeight(win)
Global HTML:TGadget = CreateHTMLView(0,0,WW,WH-100,win)
Global Replay:TGadget = CreateListBox(0,WH-100,WW,75,win)
Global prompt:TGadget = CreateTextField(0,WH-25,WW-100,25,win)
Global Go:TGadget = CreateButton("Go!",WW-100,WH-25,100,25,win,button_ok)

Global nook

Global FileMenu:TGadget = CreateMenu("File",0,WindowMenu(Win))
Global EditMenu:TGadget = CreateMenu("Edit",0,WindowMenu(Win))

CreateMenu "Save",1000,filemenu,key_S,modifier_command
?Not macos
CreateMenu "",0,filemenu
CreateMenu "Exit",0,filemenu,key_x,modifier_command
?

CreateMenu "Cut"  ,2000,editmenu,key_x,modifier_command
CreateMenu "Copy" ,2001,editmenu,key_C,modifier_command
CreateMenu "Paste",2002,editmenu,key_V,modifier_command

UpdateWindowMenu win

SetGadgetColor prompt,180,  0,255,False
SetGadgetColor prompt, 45,  0, 64,True
SetGadgetColor replay,  0,180,255,False
SetGadgetColor replay,  0, 18, 25,True

Global Workdir$ = Dirry("$AppSupport$/$LinuxDot$Phantasar Productions/DevLog")
Global PrjDir$ = Workdir+"/Projects"
Global swapdir$ = workdir+"/Swap"
Global outhtml$ = swapdir+"/HTMOUTPUT.html"

Global Project:TIni

CreateDir Prjdir,1
CreateDir swapdir,1

Const luabase$ = "if not <cmd> then DL.err('Unknown command') else <cmd>(<para>) end"

Global OLines:TList = New TList

Global htmli:Long

Type tCDPrefix
	Field CD,resetCD
	Field prefix$
End Type

Global cdprefix:TMap = New TMap


Function ECHO(T$="",FR=255,FG=255,FB=255,BR=0,BG=0,BB=0)
	If T ListAddLast Olines,"<pre style='color: #"+Right(Hex(fr),2)+Right(Hex(FG),2)+Right(Hex(FB),2)+"; backgroundcolor: #"+Right(Hex(fr),2)+Right(Hex(FG),2)+Right(Hex(FB),2)+"'>"+T+"</pre>"
	While CountList(Olines)>500 olines.removefirst() Wend
	Local bt:TStream = WriteFile(outhtml)
	WriteLine bt,"<html>~n~t<body style='color: #ffffff; background-color: #000000'>"
	For Local L$=EachIn Olines
		WriteLine bt,"~t~t"+L+"~t~t"
	Next
	WriteLine bt,"~t<a name='bottom' id='bottom'></a></body>~n</html>"
	CloseFile bt
	?macos
	HtmlViewGo html,outhtml+"#bottom"
	?win32
	htmli:+1
	HtmlViewGo html,outhtml+"?i="+htmli+"#bottom"
	?
	PollEvent
End Function
?MacOS
Const platform$ = "OS X"
?Win32
Const platform$ = "Windows"
?Linux
Const platform$ = "Linux"
?


echo "DevLog v"+MKL_NewestVersion()+" -- for "+platform
echo "Copyright Jeroen P. Broks 2016"
echo "Released under the GNU General Public License v3"
echo ""

Global entries,maxentry

Function EntryFile$()
	Return prjdir+"/"+project.c("NAME")+".Entries"
End Function

Function CountENTRIES()
	Local BT:TStream = ReadFile(EntryFile())
	Local L$
	If Not bt 
		DL.err "I cannot access: "+Entryfile()
		project = Null
		Return
	EndIf
	entries=0
	MaxEntry=0
	Local TempEntry
	While Not Eof(BT)
		L = Trim(ReadLine(BT)).toUpper()
		If Prefixed(L,"NEW:")
			tempentry = Trim(Right(L,Len(L)-4)).toint()
			entries:+1
			If tempentry>maxentry maxentry=tempentry
		EndIf	
	Wend
	echo "Entry Num: "+entries+"~nEntry Max: "+MaxEntry,0,180,255
End Function	

Function NextEntry:StringMap(BT:TStream)
	Local L$
	Local ret:StringMap = New StringMap
	Local sep,cmd$,para$
	Repeat
		If Eof(BT) Return
		L=Trim(ReadLine(BT))
	Until Prefixed(L,"NEW:")
	While Not Prefixed(L,"PUSH")
		If L And L.find(":")>=0
			cmd  = L[..L.find(":")]
			para = L[L.find(":")+1..]
			If cmd="NEW" cmd="ID"
			MapInsert ret,cmd,Trim(para)
		EndIf
		L = Trim(ReadLine(BT))	
	Wend
	Return ret
End Function		


Global lastdate$ = "Shit!"

Function cdupdate()
	Local c:tcdprefix
	ClearList project.list("CDPREFIX")
	For Local key$=EachIn MapKeys(CDPREFIX)
		c = tcdprefix(MapValueForKey(cdprefix,key))
		project.add "CDPREFIX","NEW:"+key
		project.add "CDPREFIX","CD:"+c.cd
		project.add "CDPREFIX","RESET:"+c.resetcd
		project.add "CDPREFIX","PREFIX:"+c.prefix
	Next			
End Function

Type API

        Field Commit$ = ""
	Field count   = 10

        Method Cls()
		ClearList olines
		echo
	End Method
	
	Method SETCDPREFIX(E$)
		Local p$[] = e.split(";")
		If (Len P)<4 Return err ("Invalid input. 4 parameters expected. I got "+(Len p))
		Local c:tcdprefix = New tcdprefix
		c.cd = p[1].toint()
		c.resetcd = p[2].toint()
		c.prefix = p[3]
		MapInsert cdprefix,Upper(p[0]),c
		Echo "ID: "+P[0]+"; CD: "+P[1]+"; Reset: "+P[2]+"; Prefix: "+P[3]
		project.CList "CDPREFIX"
		cdupdate
	End Method
	
	Method CDPREFIXDUMP()
		Local k$,v$
		Local dump$
		Local cd:tcdprefix
		For k$=EachIn(MapKeys(cdprefix))
			cd = tcdprefix(MapValueForKey(cdprefix,k))
			dump$:+k+" = "
			v = Replace(cd.prefix,"&","&amp;")
			v = Replace(v,"<","&lt;")
			dump:+v+"~n"
		Next
		echo dump,0,180,255
	End Method
	
	Method CDCheck()
		Local cd:tcdprefix
		Local res$
		For Local k$=EachIn(MapKeys(cdprefix))
			cd = tcdprefix(MapValueForKey(cdprefix,k))
			If res res:+"<br>"
			res:+"Auto add prefix ~q"+k+"~q after "+cd.cd+" more addition(s)"
		Next
		echo res,180,255,0,18,25,0
	End Method
	
	Method err(E$)
		ECHO "ERROR: "+E,255,0,0
	End Method
	
	Method NoProject()
		err "I don't have a project"
	End Method
	
	Method FUCK() ' This is just a joke line to test stuff out!
		echo "Hey! What kind of talk is that?",180,0,255
	End Method
	
	Method SAY(T$)
		echo T
	End Method

	Method CLOSE()
		If Not project 
			echo "No project"
			Return
		EndIf
		echo "Closing :"+Project.C("NAME")
		SaveIni prjdir+"/"+Project.C("NAME")+".prj",project
		project = Null
	End Method
	
	Method save()
		If Not project Return NoProject()
		echo "Saving"
		SaveIni prjdir+"/"+Project.C("NAME")+".prj",project
	End Method		
	
	Method ENDDEV()
		CLOSE
		End
	End Method
	
	Method SETTEMPLATE(C$)
		If Not project Return NoProject()
		Project.D "TEMPLATE",Trim(C)
	End Method
	
	Method USE(C$)
		If project close
		C = Trim(C)
		If Not Trim(C) err "What must I use?"
		project = New TIni
		Print "Reading: "+prjdir+"/"+C+".prj"
		If Not FileType(prjdir+"/"+C+".prj")
			project = Null
			dl.err "Project does not exist"
			Return
		EndIf
		LoadIni prjdir+"/"+C+".prj",project
		project.D("NAME",C)
		CountEntries
		project.CList("CDPREFIX",1)
		Local cd:Tcdprefix = New tcdprefix
		Local cdout$=""
		For Local l$=EachIn project.list("CDPREFIX")
			Local p=l.find(":")
			Local cc$=l[..p]
			Local cv$=l[p+1..]
			Select cc
				Case "ID","NEW"	cd=New tcdprefix
						MapInsert cdprefix,cv,cd
						cdout:+"~nCreated cdprefix record: "+cv
				Case "CD"	cd.cd=cv.toint()
				Case "RESET"	cd.resetcd=cv.toint()
				Case "PREFIX"	cd.prefix=cv
				Default		cdout:+"~n WARNING! Unknown command: "+l
			End Select
		Next			
		echo cdout,0,180,255
		echo "Project ok"
	End Method
	
	Method GO(C$)
		Local line$
		Local d$[] = c.split(" ")
		For Local w$ = EachIn d
		    If line line:+" "
		    If Left(w,1)="$" 
			line:+project.c("VAR."+Right(w,Len(w)-1))
		    Else
			line:+w
		    EndIf
		Next
		HtmlViewGo html,line
		nook = True
	End Method
	
	
	Method ADD(C$)
		If AddEntry(C)
 			Cls 
			last 200
			count:-1
			If count<=0 push "~n~tAuto-push" Else Echo "Auto-push after "+count+" more addition(s)"
		EndIf	
		cdcheck
	End Method
		
	Method ADDEntry(C$)
		If Not project Return dl.Err("No Project")
		c = Trim(C)
		c = Replace(c,"~n","<br>")
		Local space = C.find(" ")
		If space=-1 Return DL.Err ( "ADD: Syntax Error" )
		Local tag$=Upper(C[..space])
		Local purecontent$=C[space+1..]
		For Local k$=EachIn MapKeys(cdprefix)
			Local cd:tcdprefix = tcdprefix(MapValueForKey(cdprefix,k))
			cd.cd:-1
			If cd.cd<=0 
				purecontent = cd.prefix+" "+purecontent
				cd.cd=cd.resetcd
			Else
				echo "Auto add prefix ~q"+k+"~q after "+cd.cd+" more addition(s)"
			EndIf
			cdupdate
		Next 
		Local content$
		Local words$[] = purecontent.split(" ")
		Local word$,newword$,rsplit$[]
		For word=EachIn words
			If word.find("#")>=0
				rsplit = word.split("#")
				If word.find("\#")>=0
					newword = Replace(word,"\#","#")
				ElseIf Len(rsplit)>2
					newword = Replace(word,"\#","#")
				ElseIf Left(word,1)="#"
					If project.C("githubrepository")
						newword = "<a href='http://github.com/"+Project.c("GitHubRepository")+"/issues/"+Right(word,Len(word)-1)+"'>"+word+"</a>"
						commit:+"Devlog referred to: "+Project.c("GitHubRepository")+word+";~n"
					Else
						newword = word
						echo "WARNING! No github repository!",100,80,0
					EndIf	
				Else
					newword = "<a href='http://github.com/"+rsplit[0]+"/issues/"+rsplit[1]+"'>"+word+"</a>"
					commit:+"Devlog referred to: "+Word+";~n "
				EndIf
			ElseIf Left(word,1)="$"
				newword = project.c("VAR."+Right(word,Len(word)-1))
				If Not newword newword=word
			Else
				newword=word	
			EndIf
			If content content:+" "
			content:+newword
		Next
		project.clist("tags",True)
		If Not ListContains(project.list("tags"),tag) Return dl.err( "Tag ~q"+tag+"~q does not exist!" )
		ListAddLast OLines,"<span style='"+project.C("HEAD."+tag)+"'>"+tag+":</span><span style='"+Project.C("INHD."+tag)+"'>"+content+"</span>"; echo
		Local BT:TStream = OpenFile(entryfile())
		If Not BT Then Return DL.Err("I could not write to "+EntryFile())
		SeekStream bt,StreamSize(bt)
		maxentry:+1
		Entries:+1
		WriteLine bt,"~n~nNEW: "+MaxEntry
		WriteLine bt,"~tTAG: "+tag
		WriteLine bt,"~tTEXT: "+content
		WriteLine bt,"~tPURE: "+purecontent
		WriteLine bt,"~tDATE: "+CurrentDate()
		WriteLine bt,"~tTIME: "+CurrentTime()
		WriteLine bt,"PUSH~n~n"
		CloseFile bt
		Return True
	End Method
	
	Method REMOVE(C$)
		C = Trim(C)
		If Not project Return dl.Err("No Project")
		Local BI:TStream = ReadFile(EntryFile())		If Not BI 		Return dl.err("Read error")
		Local BO:TStream = WriteFile(EntryFile()+".TEMP")	If Not bo CloseFile BI	Return dl.err("write error")		
		Local ok = False
		Local e:StringMap
		Repeat
			e = nextentry(bI)
			If Not e Exit
			If e.value("ID")=C
				ok = True
				echo "Assasinated record #"+C
			Else
				WriteLine BO,"NEW: "+e.value("ID")
				For Local key$ = EachIn MapKeys(e)
					If key<>"ID"
						WriteLine bo,"~t"+key+": "+e.value(key)
					EndIf
				Next
				WriteLine BO,"PUSH"	
			EndIf	
		Forever
		CloseFile BI
		CloseFile BO
		If Not Ok Return dl.err("Record not found")
		DeleteFile EntryFile()		
		RenameFile EntryFile()+".TEMP",EntryFile()		
	End Method
	
	Method CREATETAG(C$)
		If Not project Return dl.Err("No Project")
		SeedRnd MilliSecs()
		Local R = Rand(127,255)
		Local G = Rand(127,255)
		Local B = Rand(127,255)
		Local R2 = R/2
		Local G2 = G/2
		Local B2 = B/2
		project.clist "TAGS",True
		Local L:TList = project.list("TAGS")
		If Not ListContains(L,"SITE") 
			ListAddLast L,"SITE"
			project.D "HEAD.SITE","color: rgb("+R+","+G+","+B+"); background-color: #000000"
			project.D "INHD.SITE","color: rgb("+R+","+G+","+B+"); background-color: #040404"
		EndIf
		C = Upper(Trim(C))
		If ListContains(L,C) Return DL.Err("That tag already exists")
		ListAddLast L,C
		SortList project.list("Tags")
		project.D "HEAD."+C,"color: rgb("+R+","+G+","+B+"); background-color: #000000"
		project.D "INHD."+C,"color: rgb("+R+","+G+","+B+"); background-color: rgb("+R2+","+G2+","+B2+")"
		ADD "SITE "+"Added tag <span style='color: rgb("+R+","+G+","+B+"); background-color: rgb("+R2+","+G2+","+B2+")'>"+C+"</span>"
	End Method
	
	Method SETGITTARGET(C$)
		If Not project Return dl.Err("No Project")
		Project.D "GITTARGET",Trim(C)
	End Method

	Method SETTARGET(C$)
		If Not project Return dl.Err("No Project")
		Project.D "TARGET",Trim(C)
	End Method
	
	Method GEN()
		If Not project Return dl.Err("No Project")
		If Not Project.C("TARGET") Return dl.err("No Target")
		If Not Project.C("TEMPLATE") Return dl.err("No Template")
		Local pcTemplate$ = project.c("TEMPLATE")
		Global pcTarget$ = project.c("PCTARGET")
		DebugLog  "FPrefix = "+FPrefix+"   "+project.C("TEMPLATE."+fPrefix)+"   TEMPLATE.WIN="+Project.C("TEMPLATE.WIN")
		If project.C("TEMPLATE."+FPrefix) pcTemplate = project.C("TEMPLATE."+FPrefix) 
		If project.C("TARGET."+FPrefix) pcTarget = project.C("TARGET."+FPrefix)
		If Not FileType(PCTEMPLATE) Return dl.err("Template not found: "+pctemplate)
		Local pages = Ceil(entries/Double(200))
		Local countdown = entries
		Local cdpage
		Local BT:TStream = ReadFile(entryfile())
		Local page=pages
		DebugLog "Reading: "+PCTemplate
		Local template$ = LoadString(PCTEMPLATE)
		Local content$ = NewPage()
		Local e:StringMap
		Local eo$
		LastDate = ""
		
		Function ClosePage(content$ Var,page Var,template$,pages)
			content = "<tr valign=top><td colspan=2><big>"+lastdate+"</big></td></tr>~n"+content
			content = PageLine(pages,page)+"<p><table width='100%'><caption>Live DevLog</caption>~n"+content+"</table><p>"+PageLine(pages,page)
			echo "Saving page: "+page
			SaveString Replace(template,"@CONTENT@",content),pctarget+"/"+project.C("NAME")+"_Devlog_page"+page+".html"
			page:-1
			content =  "" 'NewPage()
			LastDate = ""
		End Function
		
		Function PageLine$(pages,page)
			Local ret$ = "Page: "
			For Local i=1 To pages
				If i=page
					ret:+"<big>"+i+"</big> "
				Else
					ret:+"<a href='"+project.C("NAME")+"_Devlog_page"+i+".html'>"+i+"</a> "
					
				EndIf
			Next
			Return ret
		End Function
		
		Function NewPage$()
			Local ret$ = "" 'PageLine()+"<p><table width='100%'><caption>Live DevLog</caption>\n"
			Return ret
		End Function
		
		While page
			cdpage = Ceil(countdown/Double(200))
			If cdpage<>page ClosePage(content,page,template,pages)
			e = nextentry(BT)
			If Not e 
				echo "WARNING! Entry underrun!",200,100,0
				closepage content,page,template,pages
				Exit
			EndIf
			If lastdate<>e.value("DATE")
				If lastdate content="<tr valign=top><td colspan=2><big>"+lastdate+"</big></td></tr>~n"+content
				lastdate=e.value("DATE")
			EndIf
			eo:+"<!-- entry #"+e.value("ID")+" -->"
			eo:+"<tr valign=top><td>"+e.value("TIME")+"</td>"
			eo:+"<td align=right style='"+project.c("HEAD."+e.value("TAG"))+"'>"+e.value("TAG")+"</td>"
			eo:+"<td style='"+project.c("INHD."+e.value("TAG"))+"'>"+e.value("TEXT")+"</td>"
			eo:+"</tr>~n"
			content = eo + content			
			eo=""
			countdown:-1
			If Not countdown closepage content,page,template,pages; Exit			
		Wend		
		CloseStream BT
	End Method
	
	Method ADDTAG(C$)
		createtag c
	End Method
	
	Method SETREPOSITORY(C$)
		project.D("GitHubRepository",Trim(C))
	End Method
	
	Method PUSH(C$)	
		save
		If Not project Return dl.Err("No Project")
		If Not Project.C("GITTARGET") Return dl.err("No Git Target")
		Local pcpush$ = Project.C("GITTARGET")
		If Project.C("GITTARGET."+fprefix) pcpush = Project.C("GITTARGET."+fprefix)
		If FileType(pcpush)<>2 Return dl.err("No dir access ("+pcpush+")")
		If FileType(pcpush+"/.git")<>2 Return dl.err("No git access in that directory  (Looking for: "+Project.C("TARGET")+"/.git)  (C"+FileType(Project.C("TARGET")+"/.git")+")")
		Local cd$ = CurrentDir()
		GEN
		ChangeDir pcpush
		echo "Git is collecting data"
		?Win32
		Local gitc$="~qC:\program files\git\bin\git~q add -A > ~q"+Replace(Swapdir,"/","\")+"GitResult.txt~q"; Print gitc
		Local gitbatch$ = gitc$
		'system_ gitc
		?Not win32
		system_ "git add -A > ~q"+Swapdir+"/GitResult.txt~q"
		?
		If Not FileType(Swapdir+"GitResult.txt") echo "Output not caught" Else echo LoadString(Swapdir+"/GitResult.txt"),255,180,0
		echo "Git is submitting"
		?win32
		gitbatch:+"~n~qC:\program files\git\Bin\git~q commit -m ~qUpdate in Windows~q"
		gitc = "~qC:\program files\git\bin\git~q commit -m ~qDevLog Update: "+CurrentDate()+"; "+CurrentTime()+" CET~n~n"+Commit+"~n~n+"+C+"~q"' > ~q"+Swapdir+"GitResult.txt~q"
		Print gitc
		'system_ gitc
		?Not win32
		system_ "git commit -m ~qDevLog Update: "+CurrentDate()+"; "+CurrentTime()+" CET~n~n"+Commit+"~n~n+"+C+"~q > ~q"+Replace(Swapdir,"\","/")+"/GitResult.txt~q"
		?
		If Not FileType(Swapdir+"GitResult.txt") echo "Output not caught" Else echo LoadString(Swapdir+"/GitResult.txt"),255,180,0
		echo "Git is pushing"
		?win32
		gitc= "~qC:\program files\git\bin\git~q push "'> ~q"+Replace(Swapdir,"/","\")+"\GitResult.txt~q"
		Print gitc
		'system_ gitc
		gitbatch:+"~n"+gitc
		gitbatch:+"~npause"
		SaveString gitbatch,"wingitpush.bat"
		system_ "wingitpush.bat"
		?Not win32
		system_ "git push > ~q"+Swapdir+"/GitResult.txt~q"
		?
		If Not FileType(Swapdir+"/GitResult.txt") echo "Output not caught" Else echo LoadString(Swapdir+"/GitResult.txt"),255,180,0
		ChangeDir cd
		Commit = ""
		count = Rand(10,20)
	End Method
	
	Method PULL()
		echo "Pulling"
		ChangeDir project.C("TARGET")
		?Not win32
		system_ "git pull > ~q"+Swapdir+"/GitResult.txt~q"
		?
		echo LoadString(swapdir+"GitResult.txt")
	End Method	

	
	Method LET(C$)
		If Not project Return dl.Err("No Project")
		Local d$[]=c.split("=")
		If (Len d)<>2 Return dl.err("invalid input")
		d[0]=Trim(d[0])
		If Left(d[0],1)="$" d[0]=Right(d[0],Len(d[0])-1)
		project.d "VAR."+Trim(d[0]),Replace(Trim(d[1]),"*is*","=")
		save
	End Method	   
	

	
	Method Tags(used$)
		If Not project Return dl.Err("No Project")
		Local o$ = "<ol type=i>"
		project.clist "TAGS",True
		SortList project.list("Tags")
		For Local t$ = EachIn project.list("Tags")
			o:+ "<li style='"+project.C("INHD."+t)+"'>"+t
			If used.toupper()="USED" 
				Local BT:TStream = ReadFile(entryfile())
				Local ln,e:StringMap,tag$
				Local u=0
				Repeat
					e = nextentry(bt)
					If Not e Exit
					If e.value("TAG")=t u:+1
				Forever
				CloseFile bt
				o:+"<br>&nbsp; = Times used: "+u
			EndIf
			o:+ "</li>"
		Next
		O:+"</ol>"
		ListAddLast olines,O; echo
	End Method
	
	Method CREATEPROJECT(C$)
		If project close
		If Not Trim(C) err "I need a project name"
		project = New TIni
		project.D "NAME",C
		SaveIni prjdir+"/"+Project.C("NAME")+".prj",project
		echo "Created: "+C,180,255,0	
		SaveString "# Project started "+CurrentDate()+"; "+CurrentTime(),prjdir+"/"+Project.C("NAME")+".entries"
		Entries=0
	End Method
	
	Method EditTag$(C$)
		If Not project Return dl.Err("No Project")
		Local cut$[]=c.split(" ")
		If (Len cut)<>2 Return err("Invalid input ("+(Len cut)+")")
		Local tag$ = Upper(cut[1])
		Local col$
		If Not ListContains(project.list("TAGS"),tag) Return err("Tag ~q"+tag+"~q does not exist")
		Select Upper(cut[0])
			Case "HEAD","INHD" col=Upper(cut[0])
			Case "CONTENT","TEXT","CNTNT" col="INHD"
			Default Return Err("Invalid collumn name ("+Upper(cut[2]))
		End Select
		SetGadgetText prompt,"MODIFYTAG "+col+" "+tag+" "+project.C(col+"."+tag)
	End Method
	
	Method ModifyTag(C$)
		If Not project Return dl.Err("No Project")
		Local cut$[] = c.split(" ")
		If (Len cut)<4 Return err("Invalid input")
		Local newstyle$
		Local col$
		Local tag$ = Upper(cut[1])
		Select Upper(cut[0])
			Case "HEAD","INHD" col=Upper(cut[0])
			Case "CONTENT","TEXT","CNTNT" col="INHD"
			Default Return Err("Invalid collumn name")
		End Select
		If Not ListContains(project.list("TAGS"),tag) Return err("Tag ~q"+tag+"~q does not exist")
		For Local i=2 Until Len cut
			If newstyle newstyle:+" "
			newstyle:+cut[i]
		Next	
		project.d col+"."+tag,newstyle
	End Method	
		
	
	Method List$(C$,gottable=False)
		Local ret$
		If Not gottable ret="<table><caption>List of "+C+"</caption>"
		If Not project Return dl.Err("No Project")
		Local mini,maxi
		Local CA$[]
		C = Trim(C)
		If Not C
			mini=0
			maxi=maxentry
		ElseIf C.find(",")>=0 
			For Local subc$=EachIn c.split(",") ret:+list(subc,True) Next
			mini=-1
		ElseIf C.find("-")>=0
			CA=c.split("-")
			mini=ca[0].toint()
			maxi=ca[1].toint()
			If maxi=0 maxi=maxentry
			If maxi<mini dl.err "Invalid definition"; Return				
		Else
			mini=c.toint()
			maxi=c.toint()	
		EndIf
		Local BT:TStream = ReadFile(entryfile())
		Local ln,e:StringMap,tag$
		Repeat
			e = nextentry(bt)
			If Not e Exit
			ln = e.value("ID").toint()
			If ln>=mini And Ln<=maxi 
				tag=e.value("TAG")
				ret:+"<tr valign=top><td align=right>"+ln+"</td><td align=right style='"+project.c("HEAD."+tag)+"'>"+Tag+"</td><td align=left width=65% style='"+project.c("INHD."+tag)+"'>"+e.value("TEXT")+"</td><td>"+e.value("DATE")+";</td><td> "+e.value("TIME")+"</td></tr>"
			EndIf
		Forever
		If Not gottable ret:+"</table>"
		If Not gottable ListAddLast olines,ret; echo
		Return ret
	End Method	
	
	Method LAST(C$)
		Local num = C.toint()
		If Not num num=200
		Local start = maxentry-num
		If start<0 start=0
		list start + "-"+maxentry + "-"
	End Method
	
	Method CLEARREPLAY(C$)
		ClearGadgetItems Replay
	End Method
	
	Method MODIFY(C$)
		Local p = c.find(" ")
		If P<0 Return err("Incorrect input")
		Local cmd$ = c[..p]
		Local txt$ = c[p+1..]
		If Not project Return dl.Err("No Project")
		Local n=cmd.toint()
		Local purecontent$=txt
		Local content$
		Local words$[] = purecontent.split(" ")
		Local word$,rsplit$[],newword$
		'Local word$,newword$,rsplit$[]
		For word=EachIn words
			If word.find("#")>=0
				rsplit = word.split("#")
				If word.find("\#")>=0
					newword = Replace(word,"\#","#")
				ElseIf Len(rsplit)>2
					newword = Replace(word,"\#","#")
				ElseIf Left(word,1)="#"
					If project.C("githubrepository")
						newword = "<a href='http://github.com/"+Project.c("GitHubRepository")+"/issues/"+Right(word,Len(word)-1)+"'>"+word+"</a>"
						commit:+"Devlog referred to: "+Project.c("GitHubRepository")+word
					Else
						newword = word
						echo "WARNING! No github repository!",100,80,0
					EndIf	
				Else
					newword = "<a href='http://github.com/"+rsplit[0]+"/issues/"+rsplit[1]+"'>"+word+"</a>"
					commit:+"Devlog referred to: "+Word+"~n"
				EndIf
			Else
				newword=word	
			EndIf
			If content content:+" "
			content:+newword
		Next
		'project.clist("tags",True)
		'If Not ListContains(project.list("tags"),tag) Return dl.err( "Tag ~q"+tag+"~q does not exist!" )
		If Not RenameFile(entryfile(),entryfile()+".temp") Return err("Sorry! Renaming to temp didn't work")		
		Local BT:TStream = WriteFile(entryfile())
		'If Not BT Then Return DL.Err("I could not write to "+EntryFile())
		'SeekStream bt,StreamSize(bt)
		'maxentry:+1
		'Entries:+1
		Local BTi:TStream = ReadFile(entryfile()+".temp")
		Local ln,e:StringMap,tag$
		Local done
		Repeat
			e = nextentry(bti)
			If Not e 
				If Not done err("Unidentified entry number") 
				Exit
			EndIf	
			ln = e.value("ID").toint()
			If ln=n
				tag = e.value("TAG")
				WriteLine bt,"~n~nNEW: "+ln
				WriteLine bt,"~tTAG: "+e.value("TAG")
				WriteLine bt,"~tTEXT: "+content
				WriteLine bt,"~tPURE: "+purecontent
				WriteLine bt,"~tDATE: "+e.value("DATE")
				WriteLine bt,"~tTIME: "+e.value("TIME")
				WriteLine bt,"~tMODIFIED"+CurrentDate()+"; "+CurrentTime()
				WriteLine bt,"PUSH~n~n"
				done = True
			Else	
				WriteLine bt,"~n~nNEW: "+e.value("ID")
				WriteLine bt,"~tTAG: " +e.value("TAG")
				WriteLine bt,"~tTEXT: "+e.value("TEXT")
				WriteLine bt,"~tPURE: "+e.value("PURE")
				WriteLine bt,"~tDATE: "+e.value("DATE")
				WriteLine bt,"~tTIME: "+e.value("TIME")
				If e.value("MODIFIED") WriteLine bt,"~tMODIFIED: "+e.value("MODIFIED")
				WriteLine bt,"PUSH~n~n"
			EndIf
		Forever
		CloseFile bti
		CloseFile bt
		ListAddLast OLines,"Changed entry #"+n+" to: <span style='"+project.C("HEAD."+tag)+"'>"+tag+":</span><span style='"+Project.C("INHD."+tag)+"'>"+content+"</span>"; echo
	End Method
	
	Method EDIT(C$)
		If Not project Return dl.Err("No Project")
		Local n=c.toint()
		Local BT:TStream = ReadFile(entryfile())
		Local ln,e:StringMap,tag$
		Repeat
			e = nextentry(bt)
			If Not e Err("Unidentified line number") Exit
			ln = e.value("ID").toint()
			If ln=n 
				If e.value("PURE")
					SetGadgetText prompt,"MODIFY "+n+" "+e.value("PURE")
				Else
					SetGadgetText prompt,"MODIFY "+n+" "+e.value("TEXT")
				EndIf
				Exit
			EndIf
		Forever
		CloseFile bt
	End Method	

	
End Type
Global DL:API = New API
LuaRegisterObject DL,"DL"

echo "Ok",0,180,255

Function Execute(C$)
	Local P$[]=C.split(" ")
	Local com$ = Upper(P[0])
	Local para$
	Local i,tp$
	Print "command = "+com
	If com="BYE" Or com="EXIT" Or Com="SUICIDE" Or COM="CALLITADAY" com="ENDDEV"
	For i=1 Until Len P
		para:+P[i]+" "
	Next
	para = Trim(Para)
	para = Replace(para,"~n","\n")
	Local Lua$ = Replace(LuaBase,"<cmd>","DL."+Upper(Com))
	Lua = Replace(Lua,"<para>","(~q"+Replace(para,"~q","\~q")+"~q)")
	DebugLog "Execute Lua~n"+Lua
	Local class:TLuaClass=TLuaClass.Create( Lua )
	If Not class Then
		DL.err("Syntax Error!")
		Return
	EndIf
	Local instance:TLuaObject=TLuaObject.Create( class,Null )	
	If Not instance
		DL.err("Syntax Error!")
	EndIf	
	If Not nook echo "Ok",0,180,255; Print "All ok"
	nook=False
End Function


ActivateGadget Prompt
Global command$
Global A:TGadget
Repeat
	A = ActiveGadget()
	If Not A A = prompt
	go.setenabled Trim(TextFieldText(prompt))<>""
	WaitEvent
	Select EventID()
		Case event_windowclose
			dl.enddev
		Case event_Gadgetaction
			If EventSource()=Go Then 
				command = GadgetText(prompt)
				echo command,180,0,255
				SetGadgetText(prompt,"")
				AddGadgetItem replay,command
				execute Trim(command)
			EndIf
		Case event_Gadgetselect
			If EventSource()=replay
				Local s = SelectedGadgetItem(replay)
				If s>=0 SetGadgetText prompt,GadgetItemText(replay,s)
			EndIf	
		Case event_menuaction
			Select EventData()
				Case 2000 GadgetCut A
				Case 2001 GadgetCopy A
				Case 2002 GadgetPaste A
			End Select	
	End Select		
Forever
