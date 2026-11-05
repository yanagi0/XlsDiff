; Diff strings, using a Longest Common Sequence algorithm,
; by word (cWordDiff class), or by character (cCharDiff class).

; TODO: Non-recursive version here: https://www.programiz.com/dsa/longest-common-subsequence


; TODO: Move into common/datatypes?
; Create a zero-based 2D array object to use for the LCS matrix.
; AHKv2 has no in-built support for 2D arrays, and arrays of arrays must be 1-based.
class Matrix2D extends Array
{
    __New(x, y)		; x & y are zero-based, so max indices are x-1, y-1
	{
		loop this.Length := x * y
			super[A_Index] := 0
        this.Width := x
        this.Height := y
    }

	; TODO: Sanity check x and y are less than Width/Height!
	__Item[x, y]	; x & y are zero-based indices
	{
        get => super[this.Width * y + x + 1]	; Have to add one to every index as underlying array is one-based.
        set => super[this.Width * y + x + 1] := value
    }
}


; Interface
class iDiffText
{
	; Return diff'd ‘old’ text in rich text format for TBC display.
	; TODO: Allow setting, and recalc. diff'd text?
	OldRich => this.strOldDiff

	; Return diff'd ‘new’ text in rich text format for TBC display.
	; TODO: Allow setting, and automatically call Update()?
	NewRich => this.strNewDiff

/*
	Removed[]
	{
	}

	Added[]
	{
	}
*/

	; {U+2424} -> New line symbol (␤); {U+240D} -> Carriage return symbol (␍)
	; TODO: This should probably replace any NL/CRs inside any Open/Close tags at all.
	indicateNLCRs(text)
	{
		static reCR := "((\Q" this.strRemovedOpen "\E|\Q" this.strAddedOpen "\E).*)`r(.*(\Q" this.strRemovedClose "\E|\Q" this.strAddedClose "\E))"
		static reNL := "((\Q" this.strRemovedOpen "\E|\Q" this.strAddedOpen "\E).*)`n(.*(\Q" this.strRemovedClose "\E|\Q" this.strAddedClose "\E))"

		text := RegExReplace(text, reCR, "$1␍`r$3")
		text := RegExReplace(text, reNL, "$1␤`n$3")
		text := StrReplace(text, "␍`r␤`n", "␍␤`r`n")
		text := StrReplace(text, "␤`n␍`r", "␤␍`n`r")

;		text := StrReplace(text, this.strRemovedOpen "`r`n" this.strRemovedClose, this.strRemovedOpen "␍␤`r`n" this.strRemovedClose)
;		text := StrReplace(text, this.strRemovedOpen "`n`r" this.strRemovedClose, this.strRemovedOpen "␤␍`n`r" this.strRemovedClose)
;		text := StrReplace(text, this.strRemovedOpen "`n"   this.strRemovedClose, this.strRemovedOpen "␤`n"    this.strRemovedClose)
;		text := StrReplace(text, this.strRemovedOpen "`r"   this.strRemovedClose, this.strRemovedOpen "␍`r"    this.strRemovedClose)

;		text := StrReplace(text, this.strAddedOpen   "`r`n" this.strAddedClose,   this.strAddedOpen   "␍␤`r`n" this.strAddedClose)
;		text := StrReplace(text, this.strAddedOpen   "`n`r" this.strAddedClose,   this.strAddedOpen   "␤␍`n`r" this.strAddedClose)
;		text := StrReplace(text, this.strAddedOpen   "`n"   this.strAddedClose,   this.strAddedOpen   "␤`n"    this.strAddedClose)
;		text := StrReplace(text, this.strAddedOpen   "`r"   this.strAddedClose,   this.strAddedOpen   "␍`r"    this.strAddedClose)

		return text
	}
}


class cWordDiff extends iDiffText
{
	strStart := "{silver}"
	strRemovedOpen := "{st}{red}"
	strRemovedClose := "{/red}{/st}"
	strAddedOpen := "{ul}{green}"
	strAddedClose := "{/green}{/ul}"
	strEnd := "{/silver}"

	__New(strOld, strNew)
	{
		this.strOld := strOld
		this.strNew := strNew
		; Break down the input into elements (either words and whatever is in-between words).
		this.oldElements := this.strExplode(strOld)
		this.newElements := this.strExplode(strNew)

		this.makeLCSMatrix()
		this.strLCS := SubStr(this.backtraceLCSMatrix(this.oldElements.Length, this.newElements.Length), 1, -1)
		; TODO: Defer doing this until OldRich[] or NewRich[] are called. They should cache the result.
		this.doDiff()
	}

	; Generate the diff'd strings.
	doDiff()
	{
		; Now we have the LCS, walk along it, and highlight differences in the two strings.
		; Strikethrough/red in old text, underline/green in new text.
		iPrev := jPrev := 0
		this.strOldDiff := this.strNewDiff := ""
		Loop Parse, this.strLCS, ","
		{
			; Each 'A_LoopField' is the index of an element (word or between-word) in the oldElements list.
			thisElement := this.oldElements[A_LoopField]

			; Find the next element after position iPrev in the oldElements list that matches this element.
			;   If that's more than just the next element in the oldElements list, we have removed elements, so highlight them.
			if (i := this.nextMatch(thisElement, this.oldElements, iPrev)) > iPrev+1
				this.strOldDiff .= this.strRemovedOpen this.concatElements(this.oldElements, iPrev+1, i-1) this.strRemovedClose

			; Find the next element starting at position jPrev in the newElements list that matches this element.
			;   If that's more than just the next element in the newElements list, we have added elements, so highlight them.
			if (j := this.nextMatch(thisElement, this.newElements, jPrev)) > jPrev+1
				this.strNewDiff .= this.strAddedOpen this.concatElements(this.newElements, jPrev+1, j-1) this.strAddedClose

			; Add the common element to both strings, or if the end of the list, anything left over.
			this.strOldDiff .= i ? this.oldElements[i] : this.strRemovedOpen this.concatElements(this.oldElements, iPrev+1, this.oldElements.Length) this.strRemovedClose
			this.strNewDiff .= j ? this.newElements[j] : this.strAddedOpen this.concatElements(this.newElements, jPrev+1,  this.newElements.Length) this.strAddedClose
			iPrev := i, jPrev := j
		}

		; Add start and end tags.
		this.strOldDiff := this.strStart this.strOldDiff this.strEnd
		this.strNewDiff := this.strStart this.strNewDiff this.strEnd

		; Replace any newlines/CRs that are the only difference with symbols so they're visible.
		this.strOldDiff := this.indicateNLCRs(this.strOldDiff)
		this.strNewDiff := this.indicateNLCRs(this.strNewDiff)
	}

	; Find the next occurrence of strNeedle in the arrHaystack after nElement
	nextMatch(strNeedle, arrHaystack, nElement)
	{
		while ++nElement <= arrHaystack.Length
			if strNeedle == arrHaystack[nElement]
				return nElement
	}

	; Concatenate all elements in the given array between indices nStart and nEnd inclusive.
	concatElements(arrHaystack, nStart, nEnd)
	{
		loop nEnd-nStart+1
			strConcat .= arrHaystack[nStart+A_Index-1]
		return strConcat
	}

	; Breaks a string down into an array of words and in-between words.
	strExplode(strText)
	{
		Output := Array()
		nPos := 1
		Match := ""
		while nPos := RegExMatch(strText, ".+?(\b|$)", &Match, nPos) + (Match?StrLen(Match[]):0)	; Match[] returns the overall match or a captured subpattern.
			Output.Push(Match[])
		return Output
	}

	; Generate the LCS matrix based on the new and old words.
	makeLCSMatrix()
	{
		this.LCSMatrix := Matrix2D(this.oldElements.Length+1, this.newElements.Length+1)

		this.LCSMatrix[0, 0] := 0
		while (i := A_Index) <= this.oldElements.Length
		{
			this.LCSMatrix[i, 0] := 0
			while (j := A_Index) <= this.newElements.Length
			{
				if this.oldElements[i] == this.newElements[j]		; Case-sensitive ==
					this.LCSMatrix[i, j] := this.LCSMatrix[i-1, j-1] + 1
				else
					this.LCSMatrix[i, j] := ((left := this.LCSMatrix[i-1, j]) > (above := this.LCSMatrix[i, j-1])) ? left : above
			}
		}
	}

	; Read out one possible LCS from a pre-calculated matrix.
	; Basically returns a comma-separated list (string) of index numbers of oldElements that are present in sequence in newElements.
	; NB: There will be a comma on the end.
	; This function is recursive.
	backtraceLCSMatrix(i, j)
	{
		if i = 0 or j = 0
			return ""

		if this.oldElements[i] == this.newElements[j]
			return this.backtraceLCSMatrix(i-1, j-1) . i ","	; Elements match at this point, so go up AND left.

		; The words don't match, so we follow the highest number to the left or above, with ‘above’ taking precedence.
		if this.LCSMatrix[i, j-1] > this.LCSMatrix[i-1, j]
			return this.backtraceLCSMatrix(i, j-1)
		else
			return this.backtraceLCSMatrix(i-1, j)
	}

	; For debugging.
	listElements()
	{
		strElements := "Old elements:`n"
		loop this.oldElements.Length
			strElements .= A_Index ": " this.oldElements[A_Index] "`n"
		strElements .= "`n`nNew elements:`n"
		loop this.newElements.Length
			strElements .= A_Index ": " this.newElements[A_Index] "`n"
		return strElements
	}
}




class cCharDiff extends iDiffText
{
	strStart := "{silver}"
	strRemovedOpen := "{st}{red}"
	strRemovedClose := "{/red}{/st}"
	strAddedOpen := "{ul}{green}"
	strAddedClose := "{/green}{/ul}"
	strEnd := "{/silver}"

	__New(strOld, strNew)
	{
		this.strOld := strOld
		this.strNew := strNew

		this.makeLCSMatrix()
		this.strLCS := this.backtraceLCSMatrix(StrLen(this.strOld), StrLen(this.strNew))
		; TODO: Defer doing this until OldRich[] or NewRich[] are called. They should cache the result.
		this.doDiff()
	}

	; Now we have the LCS, walk along it, and highlight differences in the two strings.
	; Strikethrough and red in old text red, and underline and green in new text.
	doDiff()
	{
		iPrev := jPrev := 0
		strOldDiff := this.strOld
		strNewDiff := this.strNew
		while A_Index <= StrLen(this.strLCS)
		{
			strThisChar := SubStr(this.strLCS, A_Index, 1)
			; MsgBox, % "strThisChar: " strThisChar "`ni: " i ", iPrev: " iPrev "`nj: " j ", jPrev: " jPrev "`nstrOldDiff: " strOldDiff "`nstrNewDiff: " strNewDiff

			if (i := InStr(strOldDiff, strThisChar, true, iPrev+1)) > iPrev+1
				this.insertAround(&strOldDiff, iPrev+1, &i, this.strRemovedOpen,  this.strRemovedClose)

			if (j := InStr(strNewDiff, strThisChar, true, jPrev+1)) > jPrev+1
				this.insertAround(&strNewDiff, jPrev+1, &j, this.strAddedOpen, this.strAddedClose)

			iPrev := i, jPrev := j
		}

		; Process any leftover text.
		if (nOldLen := StrLen(strOldDiff)+1) > iPrev+1
			this.insertAround(&strOldDiff, iPrev+1, &nOldLen, this.strRemovedOpen,  this.strRemovedClose)

		if (nNewLen := StrLen(strNewDiff)+1) > jPrev+1
			this.insertAround(&strNewDiff, jPrev+1, &nNewLen, this.strAddedOpen, this.strAddedClose)

		; Add start and end tags.
		this.strOldDiff := this.strStart strOldDiff this.strEnd
		this.strNewDiff := this.strStart strNewDiff this.strEnd

		; Replace any newlines/CRs that are the only difference with symbols so they're visible.
		this.strOldDiff := this.indicateNLCRs(this.strOldDiff)
		this.strNewDiff := this.indicateNLCRs(this.strNewDiff)
	}

	; Insert strOpen and strClose into strString.
	; strOpen is inserted at nStart; strClose is inserted at nEnd-1
	; nEnd is updated to be moved forward by the length of strOpen and strClose.
	insertAround(&strString, nStart, &nEnd, strOpen, strClose)
	{
		strString := SubStr(strString, 1, nStart-1) . strOpen . SubStr(strString, nStart, nEnd-nStart) . strClose . SubStr(strString, nEnd)
		nEnd += StrLen(strOpen) + StrLen(strClose)
	}

	; Compute the LCS matrix for two strings, strNew and strOld
	makeLCSMatrix()
	{
		;MsgBox("New, i: " StrLen(this.strNew)+1 "`nOld, j: " StrLen(this.strOld)+1)
		this.LCSMatrix := Matrix2D(StrLen(this.strOld)+1, StrLen(this.strNew)+1)

		this.LCSMatrix[0, 0] := 0
		while (i := A_Index) <= StrLen(this.strOld)
		{
			this.LCSMatrix[i, 0] := 0
			while (j := A_Index) <= StrLen(this.strNew)
			{
				;MsgBox("i: " i "`nj: " j)
				if SubStr(this.strOld, i, 1) == SubStr(this.strNew, j, 1)		; Case-sensitive ==
					this.LCSMatrix[i, j] := this.LCSMatrix[i-1, j-1] + 1
				else
					this.LCSMatrix[i, j] := ((left := this.LCSMatrix[i-1, j]) > (above := this.LCSMatrix[i, j-1])) ? left : above
			}
		}
	}

	; Read out one possible LCS from a pre-calculated matrix.
	; This function is recursive.
	backtraceLCSMatrix(i, j)
	{
		if i = 0 or j = 0
			return ""

		if (strOldChar := SubStr(this.strOld, i, 1)) == SubStr(this.strNew, j, 1)
			return this.backtraceLCSMatrix(i-1, j-1) . strOldChar	; Chars match at this point, so go up AND left.

		; The characters don't match, so we follow the highest number to the left or above, with ‘above’ taking precedence.
		if this.LCSMatrix[i, j-1] > this.LCSMatrix[i-1, j]
			return this.backtraceLCSMatrix(i, j-1)
		else
			return this.backtraceLCSMatrix(i-1, j)
	}
}
