use data.nu

export def image-loader [uri: string] {
    let img = if ($uri | path exists) {
        let b =  open $uri | encode base64
        let t = $uri | path parse | get extension | str downcase
        let t = match $t {
            'jpg' | 'jpeg' => 'jpeg'
            _ => $t
        }
        {url: $"data:image/($t);base64,($b)"}
    } else {
        $uri
    }
}

export def openai-req [
    --role(-r): string = 'user'
    --image(-i): string
    --audio(-a): string
    --tool-calls: string
    --tool-call-id: string
    --functions(-f): list<any>
    --model(-m): string
    --temperature(-t): number = 0.5
    --stream
    message?: string
] {
    mut o = $in | default { messages: [] }
    if $role not-in [user assistant system tool function] {
        error make { msg: $"unsupport role ($role)"}
    }
    if ($model | is-not-empty) {
        $o.model = $model
    }
    if ($temperature | is-not-empty) {
        $o.temperature =  $temperature
    }
    if ($functions | is-not-empty) {
        $o.tools = $functions
        $o.tool_choice = 'auto'
    }
    $o.stream = $stream
    let content = if not (($image | is-empty) and ($audio | is-empty)) {
        mut content = []
        if ($message | is-not-empty) {
            $content ++= [{type: text, text: $message}]
        }
        if ($image | is-not-empty) {
            $content ++= [{type: image_url, image_url: (image-loader $image) }]
        }
        $content
    } else {
        $message
    }

    mut m = {role: $role, content: $content}
    if ($tool_calls | is-not-empty) {
        $m.tool_calls = $tool_calls
    }
    if ($tool_call_id | is-not-empty) {
        $m.tool_call_id = $tool_call_id
    }

    if ($content | is-not-empty) or ($tool_calls | is-not-empty) {
        $o.messages = $o.messages ++ [$m]
    }

    $o
}

export def openai-call [
    session
    --quiet(-q)
] {
    let $req = $in
    let r = http post -r -e -t application/json --headers [
            Authorization $"Bearer ($session.api_key)"
    ] $"($session.baseurl)/chat/completions" $req
    | lines
    | reduce -f {msg: '', token: 0, tools: []} {|i,a|
        let x = $i | parse -r '.*?(?<data>\{.*)'
        if ($x | is-empty) { return $a }
        let x = $x | get 0.data | from json

        if 'error' in $x {
            error make {
                msg: ($x.error | to yaml)
            }
        }

        let tools = $x.choices
        | each {|i|
            if 'tool_calls' in $i.delta { [$i.delta.tool_calls] } else { [] }
        }
        | flatten
        | flatten

        let m = $x.choices
        | each {
            let i = $in
            let s = $i.delta.content? | default ''
            if not $quiet { print -n $s }
            let cf = $env.AI_CONFIG.finish_reason
            if $cf.enable and ($i.finish_reason? | is-not-empty) {
                print -e $"(ansi $cf.color)<($i.finish_reason)>(ansi reset)"
            }
            $s
        }
        | str join

        $a
        | update msg {|x| $x.msg + $m }
        | update tools {|x| $x.tools | append $tools }
        | update token {|x| $x.token + 1 }
    }
    let tools = if ($r.tools | is-empty) {
        []
    } else {
        $r.tools
        | each {|x|
            let v = $x
            | upsert id {|y| [($y.id? | default '')] }
            | upsert function.name {|y| [($y.function?.name? | default '')] }
            | upsert function.arguments {|y|
                [($y.function?.arguments? | default '')]
            }
            let k = $x.index? | default 0
            {$k: $v}
        }
        | reduce {|i,a|
            $a | merge deep $i --strategy=append
        }
        | items {|k, v| $v }
        | update id {|y| $y.id | str join }
        | update function.name {|y| $y.function.name | str join }
        | update function.arguments {|y| $y.function.arguments | str join }
    }
    $r | update tools $tools
}

export def ai-req [
    session
    message?: string
    --role(-r): string = 'user'
    --image(-i): string
    --audio(-a): string
    --tool-calls: string
    --tool-call-id: string
    --functions(-f): list<any>
    --model(-m): string
    --temperature(-t): number = 0.5
    --stream
] {
    let o = $in
    match $session.adapter? {
        _ => (
            $o | openai-req
            --role $role
            --image $image
            --audio $audio
            --tool-calls $tool_calls
            --tool-call-id $tool_call_id
            --functions $functions
            --model $model
            --temperature $temperature
            --stream=$stream
            $message
        )
    }
}

export def ai-call [
    session
    --tag: string = ''
    --quiet(-q)
    --record:int = 1
] {
    let req = $in
    match $session.adapter? {
        _ => {
            let msg = $req | get messages | slice (-1 * $record)..-1
            for x in $msg {
                let tc = if ($x.tool_call_id? | is-not-empty) { $x.tool_call_id }
                data record $session $x.role $x.content --tag $tag --tools $tc
            }
            let r = $req | ai-req $session --stream | openai-call $session --quiet=$quiet
            let tc = if ($r.tools? | is-not-empty) { $r.tools | to yaml }
            data record $session 'assistant' $r.msg --token $r.token --tag $tag --tools $tc
            $r
        }
    }
}

export def ai-models [] {

}
