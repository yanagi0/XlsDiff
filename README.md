# XlsDiff

An AutoHotkey v2 script that shows the differences between two pieces of text, built mainly for comparing cells in Excel.

Removed text is shown struck through in red, and added text is underlined in green. If the new text is mostly Latin characters, the diff is done word by word; otherwise (for example, Japanese) it is done character by character. Both use a longest-common-subsequence algorithm.

## Requirements

- Windows
- [AutoHotkey v2.0](https://www.autohotkey.com/) or later
- Microsoft Excel (for the Excel hotkey)

## Usage

Run `XlsDiff.ahk`. Everything it needs is in the `Lib` folder.

**In Excel** (when not editing a cell), press **Ctrl+Win+D**:

- **Two cells selected** (two separate areas, or a range with exactly two visible cells, e.g. in a filtered list): the first is treated as the old text, the second as the new.
- **One cell selected**: it's compared with the cell at the offset remembered from the last two-area selection (by default, the cell to its left).

A short press shows the diff in a tooltip. A long press (half a second) opens the Diff Text window instead.

**Anywhere else**, Ctrl+Win+D opens the Diff Text window: paste the old and new text into the two boxes and click **Go**.

## Files

| File | Contents |
|---|---|
| `XlsDiff.ahk` | The main script and hotkeys |
| `Lib/cDiffStrings.ahk` | `cWordDiff` and `cCharDiff`: the diff algorithms |
| `Lib/cRichTooltip.ahk`, `Lib/cTooltip.ahk` | Tooltips that can show coloured and styled text |
| `Lib/cTextBoxCluster.ahk` | Lays out the styled text as a set of text controls |
| `Lib/cExcel_subset.ahk` | Helpers for finding the active Excel workbook |
| `Lib/common_subset.ahk`, `Lib/tooltip.ahk` | General helper functions |
| `Lib/debug.ahk` | Debugging helpers |

## Known issues

- Tooltip display times passed to `cRichTooltip.Show()` are ignored (they're passed as the wrong parameter), so every tooltip shows for the default 4 seconds.
- The word diff can throw an unset-variable error when it finds a difference.
- A tooltip opened with the mouse within 8 pixels of the outer right or bottom edge of the screen can throw an error.
- Diffing long passages by character can fail.

## Credits

`GetActiveObjects()` in `Lib/common_subset.ahk` is adapted to AutoHotkey v2 from [GetActiveObjects v1.0 by Lexikos](http://ahkscript.org/boards/viewtopic.php?f=6&t=6494), and is not covered by this repository's license.

## License

[MIT](LICENSE)
