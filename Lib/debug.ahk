; Debugging helpers.
;
; Use them through the global DB, which is set to cDebug at the bottom of this file:
;     DB := cDebug			; Debugging on (the default).
;     DB := NoDebugging		; Debugging off: every DB.Xxx() call does nothing and returns "".
; Assertions go through DB too, so they're turned off as well. Call cDebug.Assert() directly for any
; assertion that should stay on regardless.
;
; Per-file logging: ConsoleWrite() only writes if a global DB_<filename> exists and is true, where <filename>
; is the calling file's name without its extension (eg. DB_cEvent for cEvent.ahk). Files with the same name
; in different folders share the same flag.
;
; cDebug is a static class (its methods are called on the class itself, never on an instance). When a script
; exits, objects held in global variables are freed in no particular order, so logging from a __Delete()
; could find a DB *instance* already gone. The DB variable itself may also be cleared at exit, so wrap any
; logging in code that can run at exit (eg. __Delete) in try.
;
; #ErrorStdOut used to be in this file, but it then applied to every script that included it: a script run
; normally (with no console) showed nothing at all for a syntax error. Put it in the scripts you run from
; your editor instead.

#Requires AutoHotkey v2.0

#Include "common_subset.ahk"			; For FileReadLine().


; Swallows all debugging calls: DB := NoDebugging turns debugging off.
class NoDebugging
{
	static __Call(*)			; Any method call.
	{
	}

	static __Get(*)				; Any property read.
	{
		return ""
	}
}


class cDebug
{
	; Where ConsoleWrite() and CallStack() send their output:
	;   "stdout":      the console (eg. your editor's output pane, when the script is run from it). Lost if there's none.
	;   "OutputDebug": the debugger output (DebugView, or VS Code's debug console). Always works.
	;   "both"
	static Output := "stdout"

	; Throws an error (showing the file, line and call stack, unless caught) if bTest is false.
	static Assert(bTest, message := "<No more information>")
	{
		if not bTest
			throw Error("Assertion failed: " message, -1)	; -1: report the line that called Assert().
	}

	; Writes a message, prefixed with [calling function:line @ tick count], if the calling file's DB_<filename>
	; flag is on (see the top of this file).
	; message can be a string, or a function (eg. a fat-arrow closure) that returns one. The function is only
	; called if this file's debugging is on, so use one for messages that are expensive to build:
	;     DB.ConsoleWrite(() => "Handlers: " this.DumpHandlers())
	static ConsoleWrite(message, bAddTickCount := true, bAddFn := true)
	{
		; Each Error() walks the call stack, so only do the second one if the message will actually be written.
		CallSite := Error("", -1)		; File and line of the call to ConsoleWrite().
		SplitPath(CallSite.File, , , , &fileName := "")
		if not IsSet(DB_%fileName%) or not DB_%fileName%	; Debugging this file? (DB_<filename> unset or false: no)
			return
		if HasMethod(message)			; Deferred message: build it now we know it'll be used.
			message := message.Call()

		details := (bAddFn ? Error("", -2).What ":" : "line ") CallSite.Line	; Error("", -2).What: the calling function.
		details .= (bAddTickCount ? " @ " A_TickCount : "")
		cDebug.write("[" details "] " message)
	}

	; Sends a line of text to wherever cDebug.Output says.
	static write(text)
	{
		if cDebug.Output != "OutputDebug"
			try FileAppend(text "`n", "*")	; Throws if there's no stdout (https://www.autohotkey.com/boards/viewtopic.php?t=110850)
		if cDebug.Output != "stdout"
			OutputDebug(text)
	}

	; Returns a readable dump of any value: strings (quoted) and numbers as they are; Arrays, Maps and other
	; objects with their contents, nested up to nMaxDepth levels deep.
	static DumpVar(value, name := "", nMaxDepth := 3)
	{
		return (name != "" ? name " = " : "") cDebug.dumpValue(value, nMaxDepth, "")
	}

	static dumpValue(value, nDepth, indent)
	{
		if not IsObject(value)
			return value is String ? '"' value '"' : value
		if value is Func
			return "<" Type(value) (value.Name != "" ? " " value.Name : "") ">"
		output := "<" Type(value) ">"
		if nDepth <= 0
			return output
		indent .= "   "
		try		; Some objects (eg. COM objects) can't be enumerated.
		{
			if value is Map
				for k, v in value
					output .= "`n" indent cDebug.dumpValue(k, 0, "") " -> " cDebug.dumpValue(v, nDepth - 1, indent)
			else if value is Array
				for i, v in value
					output .= "`n" indent "[" i "] " (IsSet(v) ? cDebug.dumpValue(v, nDepth - 1, indent) : "<unset>")
			else
				for propName, v in value.OwnProps()
					output .= "`n" indent propName ": " cDebug.dumpValue(v, nDepth - 1, indent)
		}
		return output
	}

	static DumpMap(MapToDump, nameOfMap)
	{
		output := "Contents of '" nameOfMap "' map:"
		for k, v in MapToDump
			output .= "`n   " (IsObject(k) ? "<" Type(k) ">" : k) " -> " (IsObject(v) ? "<" Type(v) ">" : v)
		return output
	}

	; Hex dump, 16 bytes per line with the printable ASCII alongside.
	; data: a Buffer (or anything with Ptr and Size), or a string (dumps its UTF-16 characters, 2 bytes each).
	; For compatibility with the old DumpVarHex(&data), a reference to a variable is accepted too.
	static DumpVarHex(data)
	{
		if data is VarRef
			data := %data%
		if IsObject(data)
		{
			ptr := data.Ptr
			nSize := data.Size
		}
		else
		{
			ptr := StrPtr(data)
			nSize := StrLen(data) * 2
		}
		output := "[DumpVarHex] nSize: " nSize "`n`n"
		asciiLine := ""
		loop nSize
		{
			byteHere := NumGet(ptr, A_Index - 1, "UChar")
			output .= Format("{:02x} ", byteHere)
			asciiLine .= (byteHere > 31 and byteHere < 127) ? Chr(byteHere) : "."
			if Mod(A_Index, 16) = 0
			{
				output .= "`t" asciiLine "`n"
				asciiLine := ""
			}
		}
		if asciiLine != ""		; Pad the last, partial line so its text lines up with the lines above.
			output .= Format("{:" (16 - StrLen(asciiLine)) * 3 "}", "") "`t" asciiLine
		return output
	}

	; If bToConsole, writes each level (to wherever cDebug.Output says) and returns ""; otherwise returns them.
	static CallStack(nDeepness := 10, bPrintLines := true, bToConsole := true)
	{
		stackInfo := ""
		loop nDeepness
		{
			nLevel := -1 - nDeepness + A_Index
			ThisError := Error("", nLevel)
			PrevError := Error("", nLevel - 1)
			if ThisError.What = nLevel
				continue
			levelInfo := "File '" ThisError.File "', Line " ThisError.Line
			levelInfo .= (PrevError.What = nLevel - 1 ? "" : ", in " PrevError.What)
			if bPrintLines
				levelInfo .= ":`n`t" FileReadLine(ThisError.File, ThisError.Line)
			if bToConsole
				cDebug.write(levelInfo)
			else
				stackInfo .= "`n" levelInfo
		}
		return bToConsole ? "" : SubStr(stackInfo, 2)
	}

	; Call with GetObjectRefCount(&this) or similar.
	; When called from within an object that you're counting, the hidden "this" will be included in the count.
	; Discussion here: https://www.autohotkey.com/boards/viewtopic.php?f=82&t=124941&p=559663#p559663
	static GetObjectRefCount(&Obj)
	{
		if !IsObject(Obj)
			return ""
		ObjAddRef(address := ObjPtr(Obj))
		refCount := ObjRelease(address)
		return refCount
	}
}


; Debugging on by default. Set DB := NoDebugging (after including this file) to turn it all off.
global DB := cDebug


/*
class cGUIDebug
{
	hwndDebugDump := ""
	hwndTitle := ""
	hwndEdit := ""

	__New(strTitle := "Debug Dump", strDump := "NOT SET")
	{
		Gui, New, +hwndhwndDebugDump +LastFound
		this.hwndDebugDump := hwndDebugDump
		Gui, %hwndDebugDump%: Add, Text, +hwndhwndTitle, % strTitle
		this.hwndTitle := hwndTitle
		Gui, %hwndDebugDump%: Font, , Lucida Console
		Gui, %hwndDebugDump%: Add, Edit, ReadOnly +hwndhwndEdit, %strDump%
		this.hwndEdit := hwndEdit
		Gui, %hwndDebugDump%: Font	; Default
	}

	__Delete()
	{
		hwndDebugDump := this.hwndDebugDump
		Gui, %hwndDebugDump%: Destroy
		this.hwndDebugDump := ""
	}

	Show()
	{
		hwndDebugDump := this.hwndDebugDump
		Gui, %hwndDebugDump%: Show		;, x%myX% y%myY% w%myW%
	}

	; TODO: Doesn't resize GUI automatically
	Update(strTitle := "", strDump := "")
	{
		if (strTitle)
		{
			hwndTitle := this.hwndTitle
			GuiControl, , %hwndTitle%, % strTitle
		}

		if (strDump)
		{
			hwndEdit := this.hwndEdit
			GuiControl, , %hwndEdit%, % strDump
		}
	}
}
*/