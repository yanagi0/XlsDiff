
#Include "tooltip.ahk"

; Get mouse position relative to screen.
MouseGetScreenPos()
{
	currentMode := A_CoordModeMouse
	A_CoordModeMouse := "Screen"
	MouseGetPos(&scMouseX, &scMouseY)
	A_CoordModeMouse := currentMode
	return { scX: scMouseX, scY: scMouseY }
}


; Get caret position relative to screen.
CaretGetScreenPos()
{
	currentMode := A_CoordModeCaret
	A_CoordModeCaret := "Screen"
	bSuccess := CaretGetPos(&scCaretX, &scCaretY)
	A_CoordModeCaret := currentMode
	return bSuccess ? { scX: scCaretX, scY: scCaretY } : false
}


; Retrieve the monitor number and dimensions where the mouse is currently active.
; Returns an object (see GetMonitorInfoAt), or "" if it fails.
; For debugging:
;   MsgBox("Monitor: " MonInfo.nMonitor "`nLeft: " MonInfo.scX "`nTop: " MonInfo.scY "`nWidth: " MonInfo.pxW "`nHeight: " MonInfo.pxH)
GetActiveMonitorInfo()
{
	Mouse := MouseGetScreenPos()
	return GetMonitorInfoAt(Mouse.scX, Mouse.scY)
}


GetMonitorInfoAt(scPointX, scPointY)
{
	loop MonitorGetCount()
    {
		MonitorGet(A_Index, &scLeft, &scTop, &scRight, &scBottom)
        if (scPointX >= scLeft and scPointX <= scRight and scPointY >= scTop and scPointY <= scBottom)
			return { nMonitor: A_Index, scX: scLeft, scY: scTop, pxW: scRight-scLeft, pxH: scBottom-scTop }
    }
	return ""
}


; Detect a long key press.
; If no key is passed, assume the current hotkey, which is stripped of modifiers.
HotKeyLongPress(strKey := "", msDuration := 500)
{
	bLong := false
	sDuration := msDuration / 1000
	if (!strKey)
		strKey := RegExReplace(A_ThisHotKey, "[+!$#^]")
	if (!KeyWait(strKey, "T" sDuration))
	{
		FlashScreen()
		SoundPlay "*-1" 	; Beep
        bLong := true
		KeyWait(strKey)
	}
	return bLong
}


; Flash the currently used screen black briefly.
FlashScreen()
{
	static FullScreenGui := ""
	if not FullScreenGui
	{
		FullScreenGui := Gui("-Caption +AlwaysOnTop", "")
		FullScreenGui.BackColor := 0
		; WinSetTransparent(0, FullScreenGui)
	}
	if Monitor := GetActiveMonitorInfo()
		FullScreenGui.Show("NA x" Monitor.scX " y" Monitor.scY " w" Monitor.pxW " h" Monitor.pxH)
	else
		FullScreenGui.Show("NA x" 0 " y" 0 " w" A_ScreenWidth " h" A_ScreenHeight)
	Sleep(80)
	FullScreenGui.Hide()
}


FileReadLine(pathOfFile, nLineNumber)
{
	thisLine := ""
	loop read pathOfFile
		if A_Index = nLineNumber
		{
			thisLine := A_LoopReadLine
			break
		}
	return thisLine
}


; Not mine: GetActiveObjects v1.0 by Lexikos
; http://ahkscript.org/boards/viewtopic.php?f=6&t=6494
; WILL, Feb03, 2023: Updated naively by me to AHKv2. Seems to work on light testing.
GetActiveObjects(Prefix:="", CaseSensitive:=false)
{
	objects := Map()
	DllCall("ole32\CoGetMalloc", "uint", 1, "ptr*", &malloc := 0) ; malloc: IMalloc
	DllCall("ole32\CreateBindCtx", "uint", 0, "ptr*", &bindCtx := 0) ; bindCtx: IBindCtx
	DllCall(NumGet(NumGet(bindCtx+0, "UPtr")+8*A_PtrSize, "UPtr"), "ptr", bindCtx, "ptr*", &rot := 0) ; rot: IRunningObjectTable
	DllCall(NumGet(NumGet(rot+0, "UPtr")+9*A_PtrSize, "UPtr"), "ptr", rot, "ptr*", &enum := 0) ; enum: IEnumMoniker
	while DllCall(NumGet(NumGet(enum+0, "UPtr")+3*A_PtrSize, "UPtr"), "ptr", enum, "uint", 1, "ptr*", &mon := 0, "ptr", 0) = 0 ; mon: IMoniker
    {
        DllCall(NumGet(NumGet(mon+0, "UPtr")+20*A_PtrSize, "UPtr"), "ptr", mon, "ptr", bindCtx, "ptr", 0, "ptr*", &pname := 0) ; GetDisplayName
        name := StrGet(pname, "UTF-16")
        DllCall(NumGet(NumGet(malloc+0, "UPtr")+5*A_PtrSize, "UPtr"), "ptr", malloc, "ptr", pname) ; Free
        if (!Prefix or InStr(name, Prefix, CaseSensitive) = 1)
		{
            DllCall(NumGet(NumGet(rot+0, "UPtr")+6*A_PtrSize, "UPtr"), "ptr", rot, "ptr", mon, "ptr*", &punk := 0) ; GetObject
            ; Wrap the pointer as IDispatch if available, otherwise as IUnknown.
			try
			{
				pdsp := ComObjQuery(punk, "{00020400-0000-0000-C000-000000000046}")
                obj := ComValue(9, pdsp, 1), ObjRelease(punk)		; 9 -> VT_DISPATCH
			}
			catch
                obj := ComValue(13, punk, 1)						; 13 -> IUnknown interface pointer
            ; Store it in the return array by suffix.
            objects[SubStr(name, StrLen(Prefix) + 1)] := obj
        }
        ObjRelease(mon)
    }
    ObjRelease(enum)
    ObjRelease(rot)
    ObjRelease(bindCtx)
    ObjRelease(malloc)
    return objects
}