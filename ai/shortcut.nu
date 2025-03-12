export alias an = ai-new-session
export alias a = ai-assistant
export alias A = ai-assistant --ensure-prompt
export alias Q: = ai-assistant --response-indicator 'A: '
export alias Q： = ai-assistant --response-indicator 'A： '
export alias ad = ai-do
export alias ac = ai-chat
export alias asm = ai-switch-model
export alias asp = ai-switch-provider
export alias asn = ai-session
export alias ai-history-chat = ai-history-assistant
export alias aha = ai-history-assistant
export alias ahd = ai-history-do

export def aa [] {
    let host = $env.WHISPER_HOST? | default 'http://localhost:4010'
    let a = audio-to-text --host $host
    print $"Q: ($a)"
    ai-assistant $a --response-indicator 'A: '
}

export-env {
    $env.config.keybindings ++= [
        {
            name: ask_ai
            modifier: alt
            keycode: enter
            mode: [emacs, vi_normal, vi_insert]
            event: [
                { edit: movetolinestart },
                { edit: insertstring value: 'a '},
                { send: Enter }
            ]
        }
    ]
}
