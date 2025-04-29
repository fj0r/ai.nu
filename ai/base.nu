use data.nu
use clients/openai.nu
use clients/gemini.nu

export def ai-models [session] {
    match $session.adapter? {
        _ => {
            openai models $session
        }
    }
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
    --thinking:int
] {
    let o = $in
    match $session.adapter? {
        _ => (
            $o | openai req
            --role $role
            --image $image
            --audio $audio
            --tool-calls $tool_calls
            --tool-call-id $tool_call_id
            --functions $functions
            --model ($model | default $session.model)
            --temperature ($temperature | default $session.temperature)
            --stream=$stream
            --thinking $thinking
            $message
        )
    }
}

def debug-req [--debug] {
    let req = $in
    if $debug {
        print $"======req======"
        print $"(ansi blue)($req | to yaml)(ansi reset)"
    }
    $req
}

export def ai-call [
    session
    --tag: string = ''
    --quiet(-q)
    --debug
    --thinking:int
    --record:int = 1
] {
    let req = $in
    let msg = $req | get messages | slice (-1 * $record)..-1
    for x in $msg {
        let tc = if ($x.tool_call_id? | is-not-empty) { $x.tool_call_id }
        data record $session -r $x.role $x.content --tag $tag --tools $tc
    }
    mut f = $req.tools? | default []
    match $session.adapter? {
        gemini => {
            $f ++= [{google_search: {}}]
        }
        _ => {}
    }
    if ($session.has_search? | default 0) > 0 {
        $f = [
            {
                type: web_search
                web_search: {
                    enable: true
                }
            }
            ...$f
        ]
    }
    let r = $req
            | ai-req $session --functions $f
            | ai-req $session --stream --thinking $thinking
            | debug-req --debug=$debug
            | openai call $session --quiet=$quiet

    let tc = if ($r.tools? | is-not-empty) { $r.tools | to yaml }
    data record $session -r 'assistant' $r.content --token $r.token --tag $tag --tools $tc
    $r
}

export def req-restore [session req] {
    let o = $in
    match $session.adapter? {
        _ => {
            $o | openai req-restore $session $req
        }
    }
}


export def ai-send [
    --session(-s): record
    --role: string = 'user'
    --system: string
    --function(-f): list<any@cmpl-tools>
    --prevent-func: closure
    --image(-i): string
    --audio(-a): string
    --tool-calls: string
    --tool-call-id: string
    --tool-fallback: string
    --oneshot
    --limit: int = 20
    --quiet(-q)
    --tag: string = ''
    --req: record
    --think
    --debug
] {
    let message = $in
    let s = $session

    mut req = if ($req | is-empty) {
        mut req = ai-req $s
        if ($system | is-not-empty) {
            $req = $req | ai-req $s -r system $system
        }
        if $oneshot {
            $req
        } else {
            $req = data messages $limit | req-restore $s $req
        }
        $req
    } else {
        $req
    }
    | ai-req $s -r $role -i $image -a $audio --tool-call-id $tool_call_id --tool-calls $tool_calls $message

    let has_thinking = ($session.has_thinking? | default 1) > 0
    let thinking = if $has_thinking {
        if $think { 2 } else { 1 }
    } else {
        0
    }

    let has_fn = ($session.has_fn? | default 1) > 0
    let fns = if $has_fn and ($function | is-not-empty) {
        closure-list $function
    }
    $req = $req | ai-req $s -f $fns

    let r = $req | ai-call $s --quiet=$quiet --tag $tag --debug=$debug --thinking $thinking
    if ($fns | is-not-empty) {
        mut r = $r
        mut rst = []
        while ($r.tools | is-not-empty) {
            if ($prevent_func | is-not-empty) and (do $prevent_func $r.tools) {
                return {result: $r, req: $req}
            }
            $req = $req | ai-req $s -r assistant $r.content --tool-calls $r.tools
            let rt = closure-run $r.tools --fallback $tool_fallback
            for x in $rt {
                let msg = if err in $x {
                    $x.err
                } else {
                    $x.result | to json -rs
                }
                $req = $req
                | ai-req $s -r tool $msg --tool-call-id $x.id
            }
            if $debug { print $"(ansi blue)($req | to yaml)(ansi reset)" }
            # TODO: 0 or 1?
            $r = $req | ai-call $s --quiet=$quiet --tag $tag --thinking $thinking --record (($rt | length) + 0)
            $rst ++= [$r.content]
        }
        return {result: $r, req: $req, messages: $rst}
    }
    return {result: $r, req: $req}
}

