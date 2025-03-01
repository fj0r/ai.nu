use sqlite.nu *
use common.nu *
use function.nu *
use completion.nu *
use base.nu *
use data.nu
export use config.nu *

export-env {
    $env.AI_PROMPTS = {}
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

export def --env --wrapped ai-assistant [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
    --response-indicator: string = ''
    --complete
    --out(-o)
    --quiet(-q)
    --debug
    --refresh
    ...message: string
] {
    let input = $in
    let s = data session -p $provider -m $model
    let message = $message | str join ' '
    let message = if ($input | is-empty) {
        $message
    } else {
        $message | str replace -a '{{}}' $input
    }
    let system = if ($system | is-empty) {
        if not $env.AI_CONFIG.assistant.filled or $refresh {
            let u = do $env.AI_CONFIG.assistant.merge (data tools)
            $env.AI_CONFIG.assistant = $env.AI_CONFIG.assistant | merge deep $u
        }
        $env.AI_CONFIG.assistant.prompt
    } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let f = { type: function, function: $env.AI_CONFIG.assistant.function }
    print -n $response_indicator
    let r = (
        $message
        | ai-send -s $s
        --system $system
        --quiet=$quiet
        --debug=$debug
        --limit $env.AI_CONFIG.message_limit
        --function [$f]
        --prevent-func
    )
    mut $r = $r
    while ($r.result.tools? | is-not-empty) {
        let x = prompts-call $r {
            getter: $env.AI_CONFIG.assistant.data.getter
            prompt: $env.AI_CONFIG.assistant.data.prompt
            placeholder: $env.AI_CONFIG.assistant.data.placeholder
        }
        if ($x | describe -d).type == 'list' {
            for e in $x {
                print $e
            }
            return
        }
        if not $complete {
            # FIXME: 
            data record $s -r tool $x.result --tools $x.tools_id
            data record $s -r assistant $r.result.msg --tools $r.result.tools
            break
        } else {
            let req = $r.req
            | ai-req $s -r assistant $r.result.msg --tool-calls $r.result.tools
            $r = (
                $x.result
                | ai-send -s $s
                --quiet
                --req $req
                --role tool
                --tool-call-id $x.tools_id
                --debug=$debug
                --limit $env.AI_CONFIG.message_limit
                --function [$f]
                --prevent-func
            )
        }
    }
    if $out {
        $r.result
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
                $a | ai-send -s $s --system $system
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
    --quiet(-q)
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

    let fns = sqlx $"select tool from prompt_tools where prompt = '($args.0)'"
    | get tool
    | append $function

    let role = data role ...$args

    let r = (
        $role.template
        | render {_: $input, ...$role.vals}
        | ai-send -s $s
        --quiet=$quiet
        --system $role.system
        --function $fns
        --prevent-func=$prevent_func
        --image $image
        --tag $"($args.0)|($args | slice 1.. | str join ',')"
        --oneshot
        --debug=$debug
    )
    if $out { $r.result }
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
