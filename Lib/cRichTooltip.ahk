#Requires AutoHotkey v2.0

#Include "debug.ahk"
global DB_cRichTooltip := false
#include "common_subset.ahk"
#include "cTooltip.ahk"
#include "cTextBoxCluster.ahk"

/*
; Simple example of use:
; cRichTooltip.Show("This is a {red}tool{/red}tip`nOver {g1}{ul}two{/ul}{/g} {g2}lines{/g}!", ClickMe.Bind("testing-uno") )
; cRichTooltip.Show("This is a {blue}tool{/blue}tip`nOver {g1}{ul}two{/ul}{/g} {g2}lines{/g}!", Map(1, ClickMe.Bind("testing-uno"), 2, ClickMe.Bind("testing-due")))
cRichTooltip.Show("This is a {blue}blue text followed by {red}red and then {yellow}yellow,`nthen back to the{/yellow} last colour and back{/red} again.{/blue} The end.")
Sleep(5000)
MsgBox("Bye!")
ExitApp

ClickMe(Args, GuiControlObj, *)
{
	MsgBox("Clicked on g-label #" GuiControlObj.GLabel.iGNum " (“" GuiControlObj.GLabel.enclosedText "”)`nArgs: " Args)
}
*/


class cRichTooltip extends cTooltip
{
	static preShow()
	{
		; Create TBC inside the master GUI. The max. width is the width of the screen.
		; Set max. width to quarter width of screen.
		; TODO: TEMP: Debugging!
		if not this.TooltipGui
			Throw(Error("TooltipGui is null!"))
		; this.Meta contains GHandlers - either Func/BonndFunc object or Map() of such for each g-label.
		this.TBC := cTextBoxCluster(this.TooltipGui, this.message, this.pxHBorder, this.pxVBorder, this.Monitor.pxW/4, this.Meta, this.colBg)
		this.TBC.Show()
		this.pxW := this.TBC.pxBBWidth
		this.pxH := this.TBC.pxBBHeight
	}

	static preHide()
	{
		this.TBC := ""		; Destroy the textbox cluster
	}
}
