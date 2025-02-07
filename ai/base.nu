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

export def fabricator-openai [
    --role(-r): string = 'u'
    --image(-i): string
    --audio(-a): string
    --functions(-f): string
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
