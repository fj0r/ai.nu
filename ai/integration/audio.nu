export def audio-to-text [] {
    # FIXME:
    let a = mktemp -t XXX.mp3
    let t = mktemp -t XXX
    pw-record $a
    whisper --model small -f json --language zh $a -o
    rm -f $a $t
    open $t
}
