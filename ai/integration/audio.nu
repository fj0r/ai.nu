export def audio-request [file --host:string = 'localhost:4010'] {
    # USE: onerahmet/openai-whisper-asr-webservice:latest
    http post --content-type multipart/form-data $"http://($host)/asr" {
        audio_file: (open -r ($file | path expand))
    }
}

def audio_record [] {
    let a = mktemp -t XXX.mp3
    print $"(ansi grey)Recording started. Please speak clearly into the microphone. Press [(ansi yellow)q(ansi grey)] when finished.(ansi reset)"
    let inputfmt = match $nu.os-info.name {
        linux => 'alsa'
        windows => 'dshow'
        _ => 'avfoundation'
    }
    ffmpeg -f $inputfmt -y -loglevel error -i default -acodec libmp3lame -ar 44100 -ac 2 $a
    $a
}

export def audio-to-text [--host:string = 'localhost:4010'] {
    let a = audio_record
    print $"(ansi grey)Recording stopped. Starting recognition...(ansi reset)"
    let t = audio-request $a --host $host
    rm -f $a
    $t
}
