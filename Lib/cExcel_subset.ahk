; cExcel class, with useful functions relating to Excel.
; This is designed as a static class.

#Requires AutoHotkey v2.0

#Include "debug.ahk"
global DB_cExcel := false
#Include "common_subset.ahk"


class cExcel
{
	static EXCEL_EXE := "EXCEL.EXE"
	static EXCEL_CLASS := "XLMAIN"

	; Returns the active Excel workbook. If Excel is not active or if Excel is in edit-mode, returns false.
	static GetActiveWorkbook()
	{
		; Sometimes AHK reports a blank Wintitle/class/exe. Brief testing shows this happens when more than one Excel
		; application is open. If no hwnd exists for the active window, this attempts to activate Excel.
		if not hwndActiveWindow := WinExist("A")
		{
			WinActivate("ahk_class " this.EXCEL_CLASS)
			WinWaitActive("ahk_class " this.EXCEL_CLASS, , 1)
			hwndActiveWindow := WinExist("A")
		}

		if not hwndActiveWindow
			return false				; Excel is not active.

		if WinGetClass("A") != this.EXCEL_CLASS
			return false 				; Excel is not the active window.

		for name, Object in GetActiveObjects()
			if ComObjType(Object, "Name") = "_Workbook"
				if Object.Application.hwnd = hwndActiveWindow
					return Object.Application.ActiveWorkbook
		return false					; Not found.
	}



	; TODO: Would be nice to be able to pass an hwnd of an Excel window and find out if that window is in edit mode or not.
	; Currently this works only if Excel is the active window.
	; Tried checking for an EXCEL61 control, but there always seems to be one! Maybe checking its location would help. Or its contents...?
	static InFormulaBarOrCell()
	{
		if not hwndFocusedControl := ControlGetFocus("ahk_class " this.EXCEL_CLASS)
			return false
		classNNFocusedControl := ControlGetClassNN(hwndFocusedControl)
		return classNNFocusedControl=="EXCEL<1" or classNNFocusedControl=="EXCEL61"	; WILL, Mar21, 2024: Was: classNNFocusedControl~="^EXCEL(<|6)1$"
	}

}

