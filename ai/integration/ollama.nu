export-env {
    $env.OLLAMA_BASEURL = "http://localhost:11434"
    $env.OLLAMA_CHAT = {}
    $env.OLLAMA_HOME = [$env.HOME .ollama] | path join
}

def cmpl-models [] {
    http get $"($env.OLLAMA_BASEURL)/api/tags"
    | get models
    | each {{value: $in.name, description: $in.modified_at}}
}

export def ollama-info [--model(-m): string@cmpl-models] {
    http post -t application/json $"($env.OLLAMA_BASEURL)/api/show" {name: $model}
}

export def ollama-delete [--model(-m): string@cmpl-models] {
    http delete -t application/json $"($env.OLLAMA_BASEURL)/api/delete" -d {name: $model}
}

export def ollama-embed [
    input: string
    --model(-m): string@cmpl-models
] {
    http post -t application/json $"($env.OLLAMA_BASEURL)/api/embed" {
        model: $model, input: [$input]
    }
    | get embeddings.0
}


export def ollama-gen [
    prompt: string
    --model(-m): string@cmpl-models
    --image(-i): string
    --full(-f)
] {
    let content = $in | default ""
    let img = if ($image | is-empty) {
        {}
    } else {
        {images: [(open $image | encode base64)]}
    }
    let r = http post -t application/json $"($env.OLLAMA_BASEURL)/api/generate" {
        model: $model
        prompt: ($prompt | str replace "{}" $content)
        stream: false
        ...$img
    }
    if $full {
        $r
    } else {
        $r.response
    }
}


export def --env ollama-chat [
    message: string
    --model(-m): string@cmpl-models
    --image(-i): string
    --reset(-r)
    --oneshot
    --placehold(-p): string = '{}'
    --out(-o)
    --debug
] {
    let content = $in | default ""
    let img = if ($image | is-empty) {
        {}
    } else {
        {images: [(open $image | encode base64)]}
    }
    let msg = {
        role: "user"
        content: ($message | str replace -m $placehold $content)
        ...$img
    }
    if $debug {
        print $"(ansi grey)($msg.content)(ansi reset)"
    }
    if not $oneshot {
        if ($env.OLLAMA_CHAT | is-empty) or ($model not-in $env.OLLAMA_CHAT) {
            $env.OLLAMA_CHAT = ($env.OLLAMA_CHAT | insert $model [])
        }
        if $reset {
            $env.OLLAMA_CHAT = ($env.OLLAMA_CHAT | update $model [])
            print '✨'
        }
        $env.OLLAMA_CHAT = ($env.OLLAMA_CHAT | update $model {|x| $x | get $model | append $msg})
    }

    let r = http post -t application/json $"($env.OLLAMA_BASEURL)/api/chat" {
        model: $model
        messages: [
            ...(if $oneshot { [] } else { $env.OLLAMA_CHAT | get $model })
            $msg
        ]
        stream: true
    }
    | lines
    | reduce -f {msg: '', token: 0} {|i,a|
        let x = $i | parse -r '.*?(?<data>\{.*)'
        if ($x | is-empty) { return $a }
        let x = $x | get 0.data | from json
        let m = $x.message.content
        if not $out {
            print -n $m
        }
        $a
        | update msg {|x| $x.msg + $m }
        | update token {|x| $x.token + 1 }
    }
    if not $oneshot {
        let r = {role: 'assistant', content: $r.msg, token: $r.token}
        $env.OLLAMA_CHAT = ($env.OLLAMA_CHAT | update $model {|x| $x | get $model | append $r })
    }
    if $out { $r.msg }
}




def cmpl-ollama-model [] {
    cd $"($env.OLLAMA_HOME)/models/manifests/"
    ls **/* | where type == file | get name
}

export def ollama-export [
    target
    --model(-m): string@cmpl-ollama-model
    --home: string
] {
    if ($target | path exists) {
        if ([y n] | input list "already exists, remove it?") == 'y' {
            rm -rf $target
        } else {
            return
        }
    }
    mkdir $target

    let base = {
        blob: ([$env.OLLAMA_HOME models blobs] | path join)
        manifests: ([$env.OLLAMA_HOME models manifests] | path join)
    }

    let tg = {
        bin: ([$target model.bin] | path join)
        model: ([$target Modelfile] | path join)
        source: ([$target source.txt] | path join)
    }

    $model | split row '/' | $"($in | slice 0..<-1 | str join '/'):($in | last)" | save $tg.source


    let manifests = open ([$base.manifests $model] | path join) | from json

    for i in $manifests.layers {

        let digest = $i.digest
        let type = $i.mediaType | split row '.' | last
        let blob = [$base.blob ($i.digest | str replace ':' '-')] | path join
        match $type {
            model => {
                cp $blob $tg.bin
                $"FROM ./model.bin(char newline)" | save -a $tg.model
            }
            params => {
                let p = open $blob | from json
                $p
                | items {|k,v| {k: $k, v: $v} }
                | each {|x| $x.v | each {|y| $'PARAMETER ($x.k) "($y)"' } }
                | flatten
                | str join (char newline)
                | $"(char newline)($in)"
                | save -a $tg.model
            }
            _ => {
                $'(char newline)($type | str upcase) """(cat $blob)"""' | save -a $tg.model
            }
        }
    }

    print 'success'
}

export def ollama-import [dir] {
    cd $dir
    let model = cat source.txt
    ollama create $model
}

export def gguf-to-ollama [file --name(-n):string] {
    let name = if ($name | is-empty) {
        $file  | path basename | split row '-' | slice 0..<-1 | str join '-'
    } else {
        $name
    }
    let f = mktemp -t Modelfile.XXX.txt
    $"FROM ($file | path expand)" | save -f $f
    ollama create $name -f $f
    rm -f $f
}

