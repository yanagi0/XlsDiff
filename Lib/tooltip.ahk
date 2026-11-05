#Requires AutoHotkey v2.0



; bAtCaret only works if AHK knowns the caret location, of course. Not the case in Thunderbird, for example - always appears at mouse pointer!
TooltipVanish(textToShow := "", msTimeShown := 2000, bAtCaret := false)
{
	if (bAtCaret and Caret := CaretGetScreenPos())
		TooltipVanishAt(textToShow, Caret.scX+20, Caret.scY+20, msTimeShown)
	else
		TooltipVanishAt(textToShow)
}

; All parameters need to be optional, since this function calls itself with no params to mean "cancel the tooltip".
TooltipVanishAt(textToShow := "", scX := "", scY := "", msTimeShown := 2000)
{
	static bShowing := false
	if (textToShow)
	{
		if (bShowing)
			SetTimer(TooltipVanishAt, 0)
		if (IsInteger(scX) and IsInteger(scY))
		{
			currentMode := A_CoordModeToolTip
			A_CoordModeToolTip := "Screen"
			ToolTip(textToShow, scX, scY)
			A_CoordModeToolTip := currentMode
		}
		else
			ToolTip(textToShow)
		bShowing := true
		SetTimer(TooltipVanishAt, -msTimeShown)
	}
	else
	{
		Tooltip()
		bShowing := false
		SetTimer(TooltipVanishAt, 0)
	}
}

