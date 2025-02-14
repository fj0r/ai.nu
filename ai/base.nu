use data.nu
use clients/openai.nu
use clients/gemini.nu


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
    --record:int = 1
] {
    let req = $in
    let msg = $req | get messages | slice (-1 * $record)..-1
    for x in $msg {
        let tc = if ($x.tool_call_id? | is-not-empty) { $x.tool_call_id }
        data record $session -r $x.role $x.content --tag $tag --tools $tc
    }
    let r = match $session.adapter? {
        gemini => {
            let f = $req.tools? | default []
            let f = [...$f, {google_search: {}}]
            $req
            | ai-req $session --functions $f
            | ai-req $session --stream
            | debug-req --debug=$debug
            | openai call $session --quiet=$quiet
        }
        _ => {
            $req
            | ai-req $session --stream
            | debug-req --debug=$debug
            | openai call $session --quiet=$quiet
        }
    }

    let tc = if ($r.tools? | is-not-empty) { $r.tools | to yaml }
    data record $session -r 'assistant' $r.msg --token $r.token --tag $tag --tools $tc
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
    --prevent-func
    --image(-i): path
    --audio(-a): path
    --tool-calls: string
    --tool-call-id: string
    --oneshot
    --limit: int = 20
    --quiet(-q)
    --tag: string = ''
    --req: record
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


    let fns = if ($function | is-not-empty) {
        closure-list $function
    }
    $req = $req | ai-req $s -f $fns

    let r = $req | ai-call $s --quiet=$quiet --tag $tag --debug=$debug
    if not $prevent_func and ($fns | is-not-empty) {
        mut r = $r
        mut rst = []
        while ($r.tools | is-not-empty) {
            $req = $req | ai-req $s -r assistant $r.msg --tool-calls $r.tools
            let rt = closure-run $r.tools
            for x in $rt {
                $req = $req
                | ai-req $s -r tool ($x.result | to json -r) --tool-call-id $x.id
            }
            if $debug { print $"(ansi blue)($req | to yaml)(ansi reset)" }
            # TODO: 0 or 1?
            $r = $req | ai-call $s --quiet=$quiet --tag $tag --record (($rt | length) + 0)
            $rst ++= [$r.msg]
        }
        return {result: $r, req: $req, messages: $rst}
    }
    return {result: $r, req: $req}
}

export def prompts-call [rep c] {
    let a = $rep | get -i result.tools.0.function.arguments | default '{}' | from json
    let sn = $c.subordinate_name
    let snv = $a | get -i $sn
    let inv = $a | get -i $c.instructions
    let onv = $a | get -i $c.options
    let tlv = $a | get -i $c.tools
    let tc_color = ansi $env.AI_CONFIG.template_calls
    let rs_color = ansi reset
    if ([$a $snv $inv $snv] | any {|i| $i | is-empty} ) {
        return [
            $"($tc_color)($env.AI_CONFIG.assistant.function.name) missing args($rs_color)"
            $"(ansi grey)($a | to yaml)(ansi reset)"
        ]
    } else if $snv not-in $c.subordinates {
        return [
            $"($tc_color)($snv) not a valid subordinate name($rs_color)"
        ]
    }
    print -e $"($tc_color)[(date now | format date '%F %H:%M:%S')] ($snv) ($a | reject $sn | to nuon)($rs_color)"
    let o = $onv | default []
    let o = if ($o | describe) == 'string' { $o | from json } else { $o }
    let tc_id = $rep.result.tools.0.id
    let x = $inv | ai-do $snv ...$o -f $tlv -o
    {
        result: $x
        tools_id: $tc_id
    }
}
