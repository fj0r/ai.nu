export-env {
    if ($env.AI_TOOLS? | is-empty) {
        $env.AI_TOOLS = {}
    }
}

export def closure-list [list] {
    $list
    | reduce -f [] {|i,a|
        let p = if ($i | describe) == string {
            $env.AI_TOOLS | get -o $i
        } else {
            {schema: $i}
        }
        if ($a | where schema.name == $p.schema.name | is-empty) {
            $a | append $p
        } else {
            $a
        }
    }
    | each {|x|
        let c = $x | get -o context
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        let a = $x
        | get schema
        | select name description parameters
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                mut v = $i.v
                for j in [enum description] {
                    if ($i.v | get -o $j | describe -d).type == 'closure' {
                        let r = (do ($i.v | get $j) $c)
                        $v = $v | upsert $j $r
                    }
                }
                $a | upsert $i.k $v
            }
        }
        | upsert description {|x|
            if ($x.description | describe -d).type == 'closure' {
                do $x.description $c
            } else {
                $x.description
            }
        }
        {type: function, function: $a}
    }
}

export def ConfirmExec [msg cond act alt] {
    print $"(ansi yellow)($msg)(ansi reset)"
    if $cond and ([yes no] | input list 'confirm') == 'no' {
        let r = do $alt
        return $'### CANCELED\n($r)'
    } else {
        let r = do $act
        return $'### SUCCESS\n($r)'
    }
}

export def closure-run [list --fallback: string] {
    $list
    | par-each {|x|
        let name = $x.function.name
        let f = $env.AI_TOOLS | get -o $name
        let c = $f.context?
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        if ($f | is-empty) {
            mut e = $"function `($x.function.name)` not found."
            if ($fallback | is-not-empty) {
                $e = $"($e) try calling `($fallback)`."
            }
            print -e $"(ansi $env.AI_CONFIG.tool_calls)[(date now | format date '%F %H:%M:%S')] ($e)(ansi reset)"
            let r = $x | insert err $e
            return $r
        }
        let f = $f.handler
        let a = $x.function.arguments | from json

        if ($env.AI_CONFIG.tool_calls | is-not-empty) {
            print -e $"(ansi $env.AI_CONFIG.tool_calls)[(date now | format date '%F %H:%M:%S')] ($name) ($a | to nuon)(ansi reset)"
        }
        let c = $c | merge {
            AiSend: {|session system|
                $in | ai-send $session --system $system --oneshot --tag $"[($name)]($a)"
            }
            ConfirmExec: {|m d a| ConfirmExec $m $d $in $a }
        }
        $x | insert result (do $f $a $c)
    }
}

export def extract [o, fields] {
    if ($o | is-empty) {
        return {err: ["data"], data: null}
    }
    $fields
    | reduce -f {err: [], data: {} } {|i, a|
        let v = $o | get -o $i
        if ($v | is-empty) {
            $a | update err {|x| $x.err | append $i }
        } else {
            $a | update data {|x| $x.data | upsert $i $v }
        }
    }
}

export def prompts-call [rep c] {
    let f = $rep | get -o result.tools.0.function
    let aj = $f.arguments | default {}
    let a = $aj | from json
    let tc_id = $rep.result.tools.0.id
    let s = $c.selector
    let d = extract $a [$s.prompt $s.message $s.placeholder]
    let func = {
        function: {
            name: $env.AI_CONFIG.assistant.function.name
            arguments: $aj
        }
        id: $tc_id
        index: 0
        type: function
    }
    if $f.name != $env.AI_CONFIG.assistant.function.name {
        return {
            err: $"function name must be `($env.AI_CONFIG.assistant.function.name)`"
            function: [$func]
        }
    }
    if ($d.err | is-not-empty) {
        let e = $d.err | each {|x| $"miss `($x)`" } | str join (char newline)
        return {
            err: $e
            function: [$func]
        }
    }
    let snv = $d.data | get -o $s.prompt
    let inv = $d.data | get -o $s.message
    let onv = $d.data | get -o $s.placeholder
    let tlv = $a | get -o $s.tools
    let tc_color = ansi $env.AI_CONFIG.template_calls
    let rs_color = ansi reset
    if $snv not-in $c.prompt.name {
        return  {
            err: $"($snv) not a valid ($s.prompt)"
            function: [$func]
        }
    }
    print -e $"($tc_color)[(date now | format date '%F %H:%M:%S')] ($snv) ($a | reject $s.prompt | to nuon)($rs_color)"
    let o = $onv | default {}
    let o = if ($o | describe) == 'string' { $o | from json } else { $o }
    let pls = $c.prompt | where name == $snv | get 0.placeholder
    let pls = $pls | each {|x|
        let y = $o | get -o $x
        if ($y | is-empty) {
            let e = $c.placeholder | where name == $x | get 0.enum
            $e | columns | input list $"($tc_color)Choose a value for (ansi xterm_yellow)($x)($rs_color)"
        } else {
            $y
        }
    } | default []
    let x = $inv | ai-do $snv ...$pls -f $tlv -o
    {
        result: $x
        function: [$func]
    }
}
