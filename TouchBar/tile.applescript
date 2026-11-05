property lastPoll : -1
property animationFrame : 0
property cachedMode : "idle"
property motionStyle : "animate"
property previousLabel : ""
property cachedTitle : " "
on run
    set animationFrame to (animationFrame + 1) mod 384
    set nowTime to time of (current date)
    if nowTime is not lastPoll then
        set lastPoll to nowTime
        set cachedMode to "idle"
        set motionStyle to "animate"
        set statusPath to (POSIX path of (path to home folder)) & "Library/Application Support/MTMR/nino-status.txt"
        try
            set rows to paragraphs of (read POSIX file statusPath as «class utf8»)
            set fileInfo to info for POSIX file statusPath
            if (current date) - (modification date of fileInfo) < 35 then
                if (count of rows) > 1 then set cachedMode to item 2 of rows
                if (count of rows) > 2 then set motionStyle to item 3 of rows
            end if
            if cachedMode is not in {"idle", "think", "record", "ready", "error", "call", "transcribe", "timer"} then set cachedMode to "idle"
        end try
        set cachedTitle to " "
    end if
    set frameNumber to animationFrame mod 128
    if motionStyle is "calm" then set frameNumber to animationFrame div 3
    if motionStyle is "calm" and cachedMode is "idle" then set frameNumber to 0
    if motionStyle is "static" then set frameNumber to 0
    set imageLabel to cachedMode & "-" & frameNumber
    if previousLabel is imageLabel then return {cachedTitle}
    set previousLabel to imageLabel
    return {cachedTitle, imageLabel}
end run
