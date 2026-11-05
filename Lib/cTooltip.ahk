; Base Tooltip class from which specific types of TT are derived.

#Requires AutoHotkey v2.0
InstallKeybdHook			; Required to make A_TimeIdleKeyboard work

#Include "debug.ahk"
global DB_cTooltip := false
#Include "common_subset.ahk"

/*
#SingleInstance Force
cTooltip.Show("Hello world!")
Sleep(5000)
MsgBox("Bye!")
ExitApp
*/


class cTooltip
{
	; These must be static, as there is no constructor and they aren't evaluated otherwise.
	static pxDefaultHBorder := 4				; Default horizontal border (padding)
	static pxDefaultVBorder := 4				; Default vertical border (padding)
	static colDefaultBg := "DDEEDD"				; Default background colour
	static msDefaultDisplayPeriod := 4000		; Default display period
	static msDefaultCheckClosePeriod := 500		; Default period used to check if mouse has moved to hide tooltip
	static pxDefaultXMouseOffset := 8			; Default offset of top-right of tt from mouse pointer
	static pxDefaultYMouseOffset := 8			; Default offset of top-right of tt from mouse pointer
	static pxOpenAtMouseX := 0					; Position of mouse when tt was opened
	static pxOpenAtMouseY := 0					; Position of mouse when tt was opened
	static funcCheckHideTimer := ""
	static funcTimer := ""
	static TooltipGui := ""

	; No constructor

	static __Delete()
	{
		this.Hide()
	}

	; Default is to show at the current mouse position.
	; Meta holds metadata for classes that inherit cTooltip to use. Could be an object, or a basic type.
	; It's stored inside the cTooltip object as this.Meta.
	static Show(message, Meta := "", msDisplayPeriod := -1, colBg := "", pxHBorder := -1, pxVBorder := -1)
	{
		Mouse := MouseGetScreenPos()
		this.ShowAt(message, Mouse.scX + this.pxDefaultXMouseOffset, Mouse.scY + this.pxDefaultYMouseOffset, Meta, msDisplayPeriod, colBg, pxHBorder, pxVBorder)
	}

	; Pass 0 for msDisplayPeriod to show indefinitely.
	; -1 indicates "use the default setting".
	static ShowAt(message, scX, scY, Meta := "", msDisplayPeriod := -1, colBg := "", pxHBorder := -1, pxVBorder := -1)
	{
		; Kill any previous tt.
		this.Hide()

		; Use defaults if not specified.
		this.message := message
		this.Meta := Meta
		this.msDisplayPeriod := msDisplayPeriod := msDisplayPeriod = -1 ? this.msDefaultDisplayPeriod : msDisplayPeriod
		this.colBg := colBg := colBg ? colBg : this.colDefaultBg
		this.pxHBorder := pxHBorder := pxHBorder >= 0 ? pxHBorder : this.pxDefaultHBorder
		this.pxVBorder := pxVBorder := pxVBorder >= 0 ? pxVBorder : this.pxDefaultVBorder
		this.msCheckClosePeriod := msCheckClosePeriod := this.msDefaultCheckClosePeriod
		if msDisplayPeriod = 0
			this.msCheckClosePeriod := msCheckClosePeriod := 0			; If permanent tt, don't make mouse disappear it.

		; Find out on which screen the tt is being displayed, and get the screen dimensions.
		this.Monitor := GetMonitorInfoAt(scX, scY)

		; Create parent GUI to hold the container (HTML or TextBoxCluster currently).
		this.TooltipGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "", this)  ; +ToolWindow stops an icon appearing on the task bar.
		this.TooltipGui.BackColor := colBg

		; Add a drop shadow: https://autohotkey.com/board/topic/24934-shadow/
		; WILL, Mar25, 2023: Removed as it was causing artefacts elsewhere.
		;hwnd := this.TooltipGui.Hwnd
		;DllCall("SetClassLong", "uint", hwnd, "int", -26, "int", DllCall("GetClassLong", "uint", hwnd, "int", -26) | 0x20000)

		this.preShow()			; This creates the inner content and sets this.pxW and this.pxH

		; Nudge onto screen.
		pxW := this.pxW, pxH := this.pxH

		if (scX + pxW > this.Monitor.scX + this.Monitor.pxW)
			scX := this.Monitor.scX + this.Monitor.pxW - pxW
		else if (scX < this.Monitor.scX)
			scX := this.Monitor.scX

		if (scY + pxH > this.Monitor.scY + this.Monitor.pxH)
			scY := this.Monitor.scY + this.Monitor.pxH - pxH
		else if (scY < this.Monitor.scY)
			scY := this.Monitor.scY

		this.scX := scX, this.scY := scY

		this.msLastTimeIdleKeyboard := A_TimeIdleKeyboard
		this.TooltipGui.Show("x" scX " y" scY " w" pxW+(pxHBorder*2) " h" pxH+(pxVBorder*2) " NoActivate NA")

		; Repeatedly call checkHide() to see if the mouse has moved and if so, close the tooltip.
		; This can be overridden if msCheckClosePeriod = 0.
		Mouse := MouseGetScreenPos()
		this.scOpenAtMouseX := Mouse.scX, this.scOpenAtMouseY := Mouse.scY
		if msCheckClosePeriod > 0
			SetTimer(this.funcCheckHideTimer := ObjBindMethod(this, "checkHide"), msCheckClosePeriod)

		; Auto-close after set period.
		if msDisplayPeriod > 0
			SetTimer(this.funcTimer := ObjBindMethod(this, "Hide"), -msDisplayPeriod)
	}

	; Override in derived class to populate the tooltip GUI.
	static preShow()
	{
		scX := this.pxHBorder, scY := this.pxVBorder
		this.pxW := 400, this.pxH := 100
		this.TooltipGui.Add("Text", "x" scX " y" scY " w" this.pxW " h" this.pxH, this.message)
	}

	static Hide()
	{
		Critical("On")
		this.preHide()
		if (this.funcCheckHideTimer)
		{
			SetTimer(this.funcCheckHideTimer, 0)
			this.funcCheckHideTimer := ""
		}
		if (this.funcTimer)
		{
			SetTimer(this.funcTimer, 0)
			this.funcTimer := ""
		}
		if (this.TooltipGui)
			this.TooltipGui.Destroy()
		this.TooltipGui := ""
		Critical("Off")
	}

	; Override in derived class.
	static preHide()
	{
		; Do nothing.
	}

	; Check where the mouse is when the tt is open, and decide whether to close it or not.
	static checkHide()
	{
		if not this.TooltipGui		; In case this fires on a timer thread just as the tooltip is closed.
			return

		; Check if there's been any keyboard input.
		if A_TimeIdleKeyboard < this.msLastTimeIdleKeyboard
			return this.Hide()
		this.msLastTimeIdleKeyboard := A_TimeIdleKeyboard

		Mouse := MouseGetScreenPos()
		this.TooltipGui.GetPos(&scX, &scY, &pxW, &pxH)

		;TooltipVanish("OpenAtMouseX: " this.scOpenAtMouseX "`nOpenAtMouseY: " this.scOpenAtMouseY "`nMouseX: " Mouse.scX "`nMouseY: " Mouse.scY "`nscX: " scX "`nscY: " scY "`npxW: " pxW "`npxH: " pxH)

		; If the mouse is over the tt, don't hide it.
		; TODO: Doesn't appear to work? Update: Actually, it does, but if the tooltip's time has expired, it gets hidden by the main timer calling Hide().
		; Possibly add a "persistent during user inactivity" option, that leaves the tooltip open until user moves mouse or presses a key?
		if Mouse.scX > scX and Mouse.scX < scX+pxW and Mouse.scY > scY and Mouse.scY < scY+pxH
			return

		; If the mouse isn't over the tt, and has moved a certain amount away, close the tt.
		if abs(Mouse.scX - this.scOpenAtMouseX) > 16 or abs(Mouse.scY - this.scOpenAtMouseY) > 16
			this.Hide()
	}
}
