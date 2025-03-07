export def audio-request [file --host:string = 'localhost:4201'] {
    # USE: onerahmet/openai-whisper-asr-webservice:latest
    let t = http post --content-type multipart/form-data $"http://($host)/asr" {audio_file: (open -r ($file | path expand))}
    $t
}

export def audio-to-text [--host:string] {
    let a = mktemp -t XXX.wav
    arecord $a
    let t = audio-request $a --host $host
    rm -f $a
    $t
}
