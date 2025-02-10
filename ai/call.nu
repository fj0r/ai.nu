use sqlite.nu *
use common.nu *
use function.nu *
use completion.nu *
use base.nu *
use data.nu
export use config.nu *

export-env {
    data init
    ai-new-session
}

export def --env ai-new-session [
    --fork(-f): int
    offset?:int@cmpl-sessoin-offset
] {
    let pid = if ($fork | is-empty) {
        $env.AI_SESSION?
    } else {
        $fork
    }

    $env.AI_SESSION = data make-session

    if ($offset | is-not-empty) {
        sqlx $"update sessions set parent_id = ($pid), offset = ($offset) where id = ($env.AI_SESSION)"
    }
}

export def ai-send [
    message: string = '{}'
    --session(-s): record
    --system: string
    --function(-f): list<any@cmpl-tools>
    --prevent-func
    --image(-i): path
    --oneshot
    --placehold: string = '{}'
    --limit: int = 20
    --out(-o)
    --tag: string = ''
    --debug
] {
    let content = $in | default ""
    let content = $message | str replace --all $placehold $content
    let s = $session
    mut req = ai-req $s -m $s.model -t $s.temperature
    if ($system | is-not-empty) {
        $req = $req | ai-req $s -r system $system
    }
    if $oneshot {
        $req = $req | ai-req $s -r user -i $image $content
    } else {
        $req = data messages $limit
        | reduce -f $req {|i, a|
            # TODO: tools
            $a | ai-req $s -r $i.role $i.content
        }
        | ai-req $s -r user $content
    }

    let fns = if ($function | is-not-empty) {
        closure-list $function
    }
    $req = $req | ai-req $s -f $fns

    if $debug {
        let xxx = [
            '' 'message' $message
            'placeholder' $placehold
            'content' $content
        ] | str join "\n------\n"
        print $"(ansi blue)($xxx)(ansi reset)"
        print $"======req======"
        print $"(ansi blue)($req | to yaml)(ansi reset)"
    }
    let r = $req | ai-call $s --out=$out --tag $tag
    if ($fns | is-not-empty) {
        mut r = $r
        mut msg = $req.messages
        mut rst = []
        while ($r.tools | is-not-empty) {
            if $prevent_func { return $r }
            $req = $req | ai-req $s -r assistant $r.msg --tool-calls $r.tools
            let rt = closure-run $r.tools
            for x in $rt {
                $req = $req
                | ai-req $s -r tool ($x.result | to json -r) --tool-call-id $x.id
            }
            if $debug { print $"(ansi blue)($req | to yaml)(ansi reset)" }
            # TODO: 0 or 1?
            $r = $req | ai-call $s --out=$out --tag $tag --record (($rt | length) + 0)
            $rst ++= [$r.msg]
        }
        if $out { return $rst }
    }
    if $out { return $r.msg }
}

export def --env ai-assistant [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
    --out(-o)
    --debug
    ...message: string
] {
    let s = data session -p $provider -m $model
    let message = $message | str join ' '
    let system = if ($system | is-empty) {
        if not $env.AI_CONFIG.assistant.filled {
            let d = data tools
            $env.AI_CONFIG.assistant.prompt = $env.AI_CONFIG.assistant.prompt
            | str replace '{{templates}}' ($d.template | rename -c {placeholder:  options}  | to yaml)
            | str replace '{{placeholders}}' ($d.placeholder | to yaml)
            | str replace '{{tools}}' ($d.function | to yaml)
            $env.AI_CONFIG.assistant.function = $env.AI_CONFIG.assistant.function
            | merge deep {
                parameters: {
                    properties: {
                        subordinate_name: {
                            enum: $d.template.name
                        }
                        tools: {
                            items: {
                                enum: $d.function.name
                            }
                        }
                    }
                }
            }
            $env.AI_CONFIG.assistant.filled = true
        }
        $env.AI_CONFIG.assistant.prompt
    } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let f = { type: function, function: $env.AI_CONFIG.assistant.function }
    let r = (
        ai-send -s $s
        --system $system
        --out=$out
        --debug=$debug
        --limit $env.AI_CONFIG.message_limit
        --function [$f]
        --prevent-func
        $message
    )
    if ($r | describe) == string {
        return $r
    }
    if ($r.tools? | is-not-empty) {
        let a = $r | get -i tools.0.function.arguments | default '{}' | from json
        if ($a | is-empty) or ($a.instructions? | is-empty) or ($a.subordinate_name? | is-empty) {
            print $"(ansi $env.AI_CONFIG.template_calls)($env.AI_CONFIG.assistant.function.name) failed(ansi reset)"
            print $"(ansi grey)($a | to yaml)(ansi reset)"
            return
        }
        print -e $"(ansi $env.AI_CONFIG.template_calls)[(date now | format date '%F %H:%M:%S')] ($a.subordinate_name) ($a | reject subordinate_name | to nuon)(ansi reset)"
        let o = ensure-deserialize $a.options? | default []
        $a.instructions | ai-do $a.subordinate_name ...$o -f $a.tools?
    }
}

export def ai-chat [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
] {
    let s = data session -p $provider -m $model
    let system = if ($system | is-empty) { '' } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let p = $'😎 '
    let ci = ansi grey
    let cr = ansi reset
    let cm = ansi yellow
    let nl = char newline
    mut model = $s.model
    mut system = $system
    while true {
        let a = input $"($ci)($p)"
        let l = $a | split row -r '\s+'
        match ($l | first) {
            '\q' | 'exit' | 'quit' => { break }
            '\model' => { $model = $l | last }
            '\system' => { $system = $l | last }
            _ => {
                print -n $"✨ ($cm)"
                ai-send -s $s --system $system $a
                print $cr
            }
        }
    }
}

export def ai-editor-run [
    --watch(-w)
    --clear(-c)
    --debug
] {
    let ctx = $env.AI_EDITOR_CONTEXT?
    if ($ctx | is-empty) { error make -u { msg: "Must be run in the editor" } }
    let ctx = $ctx | from nuon
    let act = {||
        let c = open -r $ctx.file
        if ($c | is-empty) {
            print -e $"(ansi grey)no content, ignore(ansi reset)"
        } else {
            $c | ai-do ...$ctx.args --provider $ctx.provider? --model $ctx.model --function $ctx.function --image $ctx.image --debug=$debug
        }
    }
    if $ctx.action == 'ai-do' {
        if $watch {
            watch . -g $ctx.file -q {|op, path, new_path|
                if $op in ['Write'] {
                    if $clear { ansi cls }
                    do $act
                    if not $clear { print $"(char newline)(ansi grey)------(ansi reset)(char newline)" }
                }
            }
        } else {
            do $act
        }
    }
}

export def ai-do [
    ...args: string@cmpl-role
    --out(-o)
    --provider: string@cmpl-provider
    --model: string@cmpl-models
    --function(-f): list<string@cmpl-tools>
    --prevent-func
    --image(-i): path
    --previous(-p): int@cmpl-previous
    --debug
] {
    let input = $in
    let s = data session -p $provider -m $model
    let input = if ($input | is-empty) {
        if ($previous | is-not-empty) {
            sqlx $"select content from scratch where id = ($previous)" | get 0.content
        } else {
            ''
        }
        | block-edit $"($args | str join '_').XXX.temp" --context {
            action: ai-do
            args: $args
            provider: $s.provider
            model: $s.model
            function: $function
            image: $image
        }
        | tee {
            sqlx $"insert into scratch \(type, args, content, model\) values \('ai-do', (Q ($args | str join ' ')), (Q $in), (Q $s.model)\)"
        }
    } else {
        $input
    }
    let role = sqlx $"select * from prompt where name = '($args.0)'" | first
    let fns = sqlx $"select tool from prompt_tools where prompt = '($args.0)'"
    | get tool
    | append $function

    let placehold = $"<(random chars -l 6)>"

    let pls = $role.placeholder | from yaml
    let plm = $pls | each { Q $in } | str join ', '
    let plm = sqlx $"select name, yaml from placeholder where name in \(($plm)\)"
    | reduce -f {} {|i,a|
        $a | upsert $i.name ($i.yaml | from yaml)
    }

    let val = $pls
    | enumerate
    | reduce -f {} {|i,a|
        let k = $args | get -i ($i.index + 1)
        let v = $plm | get $i.item | get -i ($k | default '')
        let v = if ($v | is-empty) {
            let v = $plm | get $i.item | values | str join '|'
            $"<choose:($v)>"
        } else {
            $v
        }

        $a
        | insert $"($i.item):" $i.item
        | insert $"($i.item)" $v
    }

    let prompt = $role.template | render {_: $placehold, ...$val}
    let system = if ($role.system | is-not-empty) {
        $role.system | render $val
    }

    $input | (
        ai-send
        --session $s
        --placehold $placehold
        --system $system
        --function $fns
        --prevent-func=$prevent_func
        --image $image
        --tag ($args | str join ',')
        --oneshot
        --out=$out
        --debug=$debug
        $prompt
    )
}

export def ai-embed [
    input: string
    --provider: string@cmpl-provider
    --model: string@cmpl-models
] {
    let s = data session -p $provider -m $model
    http post -t application/json $"($s.baseurl)/embeddings" {
        model: $s.model, input: [$input], encoding_format: 'float'
    }
    | get data.0.embedding
}

export def 'similarity cosine' [a b] {
    if ($a | length) != ($b | length) {
        print "The lengths of the vectors must be equal."
    }
    $a | zip $b | reduce -f {p: 0, a: 0, b: 0} {|i,a|
        {
            p: ($a.p + ($i.0 * $i.1))
            a: ($a.a + ($i.0 * $i.0))
            b: ($a.b + ($i.1 * $i.1))
        }
    }
    | $in.p / (($in.a | math sqrt) * ($in.b | math sqrt))
}
