; Diff two pieces of text.

#Requires AutoHotkey v2.0

#Include "Lib/debug.ahk"
global DB_XlsDiff := false
#Include "Lib/common_subset.ahk"
#Include "Lib/cExcel_subset.ahk"
#Include "Lib/cRichTooltip.ahk"
#Include "Lib/cTextBoxCluster.ahk"
#Include "Lib/cDiffStrings.ahk"



; Ctrl+Win+D: Diff cells.
; TODO: Long press opens more general version with a GUI to enter two different strings?
; Could use that if comparing across different Excel files. But could also just be for general use.
^#d::
DiffText(launchKey, oldString := "", newString := "")
{
	static DiffTextGui := ""
	static pxHBorder := 8

	if not DiffTextGui
	{
		DiffTextGui := Gui( , "Diff Text")
		DiffTextGui.OldString := DiffTextGui.Add("Edit", "w240 h100")
		DiffTextGui.GoButton := DiffTextGui.Add("Button", "yp", "Go")
		DiffTextGui.GoButton.OnEvent("Click", DoDiff)
		DiffTextGui.NewString := DiffTextGui.Add("Edit", "yp w240 h100")
	}

	DiffTextGui.OldString.Text := oldString ? oldString : "<Paste old text here>"
	DiffTextGui.NewString.Text := newString ? newString : "<Paste new text here>"

	DiffTextGui.Show("h600")

	DoDiff(GuiCtrlObj, *)
	{
		; Delete old TBCs. Needs to be explicit, as setting DiffTextGui.OldDiff to "" doesn't seem to call __Delete().
		if DiffTextGui.HasOwnProp("OldDiff")
			DiffTextGui.OldDiff.__Delete()
		if DiffTextGui.HasOwnProp("NewDiff")
			DiffTextGui.NewDiff.__Delete()

		oldString := DiffTextGui.OldString.Text
		newString := DiffTextGui.NewString.Text

		; If they're identical, report and leave.
		if newString == oldString
			return cRichTooltip.Show("The old and new text are identical.", 3000)

		; If either contain no text, report and leave.
		if !newString or !oldString
			return cRichTooltip.Show("The old and/or new text is blank.", 3000)

		RegExReplace(newString, "[\x{0000}-\x{00ff}]", , &nLatin1Chars := 0)
		if bDiffByWords := (nLatin1Chars / StrLen(newString) > 0.8)
			DiffCells := cWordDiff(oldString, newString)
		else
			DiffCells := cCharDiff(oldString, newString)

		; TODO: Show if it's diff by words / chars and allow to change? (bDiffByWords?"words":"characters")

		;__New(ParentGui, text, GHandlers, pxX, pxY, pxWidth, colBg := "FFFFFF", pxLineSpacing := 20)
		DiffTextGui.OldDiff := cTextBoxCluster(DiffTextGui, DiffCells.OldRich, pxHBorder, 216, 240, "", "DDFFFF")	; y was 116, TODO: needs DPI awareness?
		DiffTextGui.NewDiff := cTextBoxCluster(DiffTextGui, DiffCells.NewRich, 260, 216, 240, "", "FFDDFF")			; y was 116, TODO: needs DPI awareness?
		DiffTextGui.OldDiff.Show()
		DiffTextGui.NewDiff.Show()
	}
}




#HotIf WinActive("ahk_class XLMAIN") and not cExcel.InFormulaBarOrCell()

; Ctrl+Win+D: Diff cells.
; Long press to open in proper diff cells dialog, otherwise display results in a tooltip.
^#d::
DiffCells(*)
{
	static rowOffset := 0
	static colOffset := -1

	bLong := HotKeyLongPress()

	if not Workbook := cExcel.GetActiveWorkbook()
		return TooltipVanish("Couldn't identify Excel workbook.")

	rngSelected := Workbook.Parent.Selection
	if rngSelected.Areas.Count > 2
		return TooltipVanish("Too many areas selected.")

	if rngSelected.Areas.Count = 1
	{
		; One range. If it's a range of two (visible) cells (the cells could be part of a filtered list),
		; assume the user wants to use the first as the old text and the second as the new text.
		if rngSelected.SpecialCells(12).Count = 2	; 12 -> xlCellTypeVisible
		{
			rngOld := rngSelected.SpecialCells(12).Areas(1).Cells(1)
			rngNew := rngSelected.SpecialCells(12).Areas(2).Cells(1)
		}
		else	; Assume the user wants to use the stored offsets. Use the first cell in the range, and the stored offset.
		{
			rngNew := rngSelected.Cells(1)
			rngOld := rngNew.Offset(rowOffset, colOffset)
		}
	}
	else
	{
		; Two ranges. Use the first cell in the first range as the old, and the first cell in the second range as the new.
		rngNew := rngSelected.Areas(2).Cells(1)
		rngOld := rngSelected.Areas(1).Cells(1)
		; Store the offsets.
		rowOffset := rngOld.Row - rngNew.Row
		colOffset := rngOld.Column - rngNew.Column
		; TooltipVanish("Updated offset to (" rowOffset ", " colOffset ").")
	}

	newString := rngNew.Value
	oldString := rngOld.Value

	if bLong
		return DiffText(A_ThisHotKey, oldString, newString)

	; If they're identical, report and leave.
	if newString == oldString
		return cRichTooltip.Show(rngOld.Address " and " rngNew.Address " contain identical text.", 3000)

	; If either contain no text, report and leave.
	if !newString or !oldString
		return cRichTooltip.Show("One or more cells contains no text.", 3000)

	; Determine if there are mainly Latin1 characters (in new text). If so, diff by word, otherwise, diff by character.
	; TODO: Override with keypress?
	RegExReplace(newString, "[\x{0000}-\x{00ff}]", , &nLatin1Chars := 0)
	if bDiffByWords := (nLatin1Chars / StrLen(newString) > 0.8)
		diffCells := cWordDiff(oldString, newString)
	else
		diffCells := cCharDiff(oldString, newString)

	cRichTooltip.Show("Diff of " rngOld.Address " and " rngNew.Address " by " (bDiffByWords?"words":"characters") ":"
					. "`nOld: " diffCells.OldRich "`nNew: " diffCells.NewRich, 7000)
}

#HotIf