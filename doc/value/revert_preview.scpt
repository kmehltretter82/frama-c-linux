  --- activate Preview
    tell application "Preview"
	activate
    end tell
    
    --- Interface with the document
    tell application "System Events"
	tell process "Preview"
	    --- Select Revert from the File menu
	    tell menu bar 1
		tell menu bar item "File"
		    tell menu 1
			click menu item "Revert"
		    end tell
		end tell
	    end tell
	    
	    --- Restore the original page (assumes standard toolbar layout)
	    --- Is there an easier way?
---	    tell window 1
---		keystroke tab & tab & tab & return
---		keystroke tab & tab & tab & tab using {shift down}
---	    end tell
	end tell
    end tell

