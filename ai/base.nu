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

export def openai-data [
    --role(-r): string = 'u'
    --image(-i): string
    --audio(-a): string
    --functions(-f): list<any>
    --model(-m): string
    --temperature(-t): number = 0.5
    message?: string
] {
    mut o = $in | default { messages: [], stream: true }
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
    let role = match ($role | str substring ..0) {
        u => 'user'
        a => 'assistant'
        s => 'system'
        _ => {
            error make { msg: $"unsupport role ($role)" }
        }
    }
    if ($content | is-not-empty) {
        $o.messages = $o.messages ++ [{role: $role, content: $content}]
    }
    $o
}

export def 'openai-call' [session --out] {
    let $req = $in
    let r = if $env.OPENAI_CONFIG.curl {
        $req | to json -r | curl -sSL -H 'Content-Type: application/json' -H $"Authorization: Bearer ($session.api_key)"  $"($session.baseurl)/chat/completions" --data @-
    } else {
        http post -e -t application/json --headers [Authorization $"Bearer ($session.api_key)"] $"($session.baseurl)/chat/completions" $req
    }
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
            if not $out { print -n $s }
            if ($env.OPENAI_CONFIG.finish_reason | is-not-empty) and ($i.finish_reason? | is-not-empty) {
                print -e $"(ansi $env.OPENAI_CONFIG.finish_reason)<($i.finish_reason)>(ansi reset)"
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
