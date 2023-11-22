; This code creates a menu based on a directory, so it is easy to change and manage without changing any code.
; This code is an adaptation of QuickLinks.ahk, by Jack Dunning.
; http://www.computoredge.com/AutoHotkey/AutoHotkey_Quicklinks_Menu_App.html
; Updated 2021-11-24:
;- Added name of menu as variable
;- Changed functions to V2 compatible
;- Submenu's with the same name are allowed now
;- Special thanks to Swagfag and Just me to fix the getExtIcon function to version V2
; Updates 2023-11-22:
; - Moved to a class


#Requires AutoHotkey v2.0-beta.1
#SingleInstance Force

Class QuickLinksMenu{ ; Just run it one time at the start.

	__New(QL_Link_Dir := "Links"){
		this.oMenu :={}
		this.QL_Link_Dir := QL_Link_Dir
		If !InStr(QL_Link_Dir, "\"){
			QL_Link_Dir := A_ScriptDir "\" QL_Link_Dir
		}

		SplitPath(QL_Link_Dir, &QL_Menu)

		If !FileExist(QL_Link_Dir){
			DirCreate(QL_Link_Dir)
		}
		FileCreateShortcut(QL_Link_Dir, QL_Link_Dir "\" QL_Menu ".lnk")
		Loop Files, QL_Link_Dir "\*.*", "FR"
		{
			if InStr(A_LoopFileAttrib, "H") or InStr(A_LoopFileAttrib, "R")  or InStr(A_LoopFileAttrib, "S") ;Skip any file that is H, R, or S (System).
				continue

			Folder1  := RegExReplace(A_Loopfilefullpath, "(.*\\[^\\]*)\\([^\\]*)\\([^\\]*)", "$2")
			Folder1Menu  := QL_Menu StrReplace(StrReplace(RegExReplace(A_Loopfilefullpath, "(.*\\[^\\]*\\[^\\]*)\\([^\\]*)", "$1"), QL_Link_Dir), "\")
			Folder2Menu  := QL_Menu StrReplace(StrReplace(RegExReplace(A_Loopfilefullpath, "(.*\\[^\\]*)\\([^\\]*)\\([^\\]*)", "$1"), QL_Link_Dir), "\")

			Linkname := StrReplace(A_LoopFileName, ".lnk")

			if !this.oMenu.HasOwnProp(Folder1Menu){
				this.oMenu.%Folder1Menu% := Menu()
			}

			this.oMenu.%Folder1Menu%.Add(Linkname, ((Functon1, Parameter,*)=>(%Functon1%(Parameter))).Bind("Run",A_Loopfilefullpath))
			this.Icon_Add(this.oMenu.%Folder1Menu%,Linkname,A_LoopFilePath) ; icon
			if !this.oMenu.HasOwnProp(Folder2Menu) {
				this.oMenu.%Folder2Menu% := Menu()
			}

			this.oMenu.%Folder2Menu%.Add(Folder1, this.oMenu.%Folder1Menu%) ; Create submenu
			this.oMenu.%Folder2Menu%.SetIcon(Folder1, A_Windir "\syswow64\SHELL32.dll", "5") ; icon for folder
		}
		return this.oMenu
	}

	Show(){
		this.oMenu.%this.QL_Link_Dir%.Show()
	}

	Icon_Add(menuitem,submenu,LoopFileFullPath){ ; add icon based on extention or name
		If InStr(LoopFileFullPath, ".lnk"){
			FileGetShortcut(LoopFileFullPath, &File, , , , &OutIcon, &OutIconNum)
			 if (OutIcon != "") {
				menuitem.SetIcon(submenu, OutIcon, OutIconNum)
				return
			}
		}
		Else{
			File := LoopFileFullPath
		}

		if InStr(FileExist(File),"D"){
			menuitem.SetIcon(submenu, A_Windir "\syswow64\SHELL32.dll", "5")
			return
		}
		Extension  := RegExReplace(File, "([^\.]*)(\.[^\.]*).*", "$2")
		Extension2  := RegExReplace(File, "([^\.]*)(\..*)", "$2")
		Icon_nr := 0
		If (Extension = ".exe"){
			try {
				menuitem.SetIcon(submenu, file, "1")
			}
			return
		}

		IconFile := this.getExtIcon(StrReplace(Extension, "."))

		If InStr(Extension, "\")
			menuitem.SetIcon(submenu, A_Windir "\syswow64\SHELL32.dll", "5")
		Else If (Extension = ".ahk")
			menuitem.SetIcon(submenu, "autohotkey.exe", "2")
		Else If (Extension ~= "i)\.(jpg|png)")
			menuitem.SetIcon(submenu, A_Windir "\system32\Imageres.dll", "68")
		Else If (Extension = ".txt")
			menuitem.SetIcon(submenu, A_Windir "\syswow64\Notepad.exe", "0")
		Else If InStr(IconFile, " - "){
			try{
				RegExMatch(IconFile,"(.*) - (\d*)", &IconFile)
				menuitem.SetIcon(submenu, IconFile[1], IconFile[2])
			}
			Catch{
				MsgBox(IconFile[1] "`n" IconFile[2] "`next:" Extension)
			}
			return
		}
		Return
	}

	getExtIcon(Ext) {

		from := RegRead("HKEY_CLASSES_ROOT\." Ext)
		DefaultIcon := RegRead("HKEY_CLASSES_ROOT\" from "\DefaultIcon")
		DefaultIcon := StrReplace(DefaultIcon, '"')
		DefaultIcon := StrReplace(DefaultIcon, "%SystemRoot%", A_WinDir)
		DefaultIcon := StrReplace(DefaultIcon, "%ProgramFiles%", A_ProgramFiles)
		DefaultIcon := StrReplace(DefaultIcon, "%windir%", A_WinDir)

		I := StrSplit(DefaultIcon, ",")

		Return I[1] " - " this.IndexOfIconResource(I[1], RegExReplace(I[2], "[^\d]+"))
	}

	IndexOfIconResource(Filename, ID) {
		; If the DLL isn't already loaded, load it as a data file.
		If !DllCall("GetModuleHandle", "Str", Filename, "UPtr")
			HMOD := DllCall("LoadLibraryEx", "Str", Filename, "Ptr", 0, "UInt", 0x02, "UPtr")
		EnumProc := CallbackCreate(IndexOfIconResource_EnumIconResources, "F")
		Param := Buffer(12, 0)
		NumPut("UInt", ID, Param)
		; Enumerate the icon group resources. (RT_GROUP_ICON=14)
		DllCall("EnumResourceNames", "Ptr", HMOD, "UInt", 14, "Ptr", EnumProc, "Ptr", Param)
		CallbackFree(EnumProc)
		; If we loaded the DLL, free it now.
		If (HMOD)
			DllCall("FreeLibrary", "Ptr", HMOD)
		Return (NumGet(Param, 8, "UInt")) ? NumGet(Param, 4, "UInt") : 0
	}
}

IndexOfIconResource_EnumIconResources(hModule, lpszType, lpszName, lParam) {
	NumPut("UInt", NumGet(lParam + 4, "UInt") + 1, lParam + 4)
	If (lpszName = NumGet(lParam, "UInt")) {
		NumPut("UInt", 1, lParam + 8)
		Return False	; break
	}
	Return True
}
