export-env {
    $env.AI_TOOLS = {}
}

export def closure-list [list] {
    $list
    | uniq
    | each {|x|
        let a = $env.AI_TOOLS | get $x
        | get schema
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                let v = if ('enum' in $i.v) and ($i.v.enum | describe -d).type == 'closure' {
                    let c = $env.AI_TOOLS | get -i $x | get -i config
                    let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
                    $i.v | upsert enum (do $i.v.enum $c)
                } else {
                    $i.v
                }
                $a | insert $i.k $v
            }
        }
        {type: function, function: ($a | upsert name $x)}
    }
}

export def closure-run [list] {
    $list
    | par-each {|x|
        let name = $x.function.name
        let f = $env.AI_TOOLS | get -i $name
        let c = $f.config?
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        if ($f | is-empty) { return $"Err: function ($x.function.name) not found" }
        let f = $f.handler
        let a = $x.function.arguments | from json

        if ($env.AI_CONFIG.tool_calls | is-not-empty) {
            print -e $"(ansi $env.AI_CONFIG.tool_calls)[(date now | format date '%F %H:%M:%S')] ($name) ($a | to nuon)(ansi reset)"
        }
        $x | insert result (do $f $a $c)
    }
}


use completion.nu *

export def func-list [...fns:string@cmpl-nu-function] {
    scope commands
    | where name in $fns
    | each { func-to-json $in }
    | each {|x| {type: function, function: ($x | update parameters {|y| $y.parameters.value}), flags: $x.parameters.flags} }
}

export def func-to-json [fn] {
    $fn
    | insert parameters {|x|
        let x = $x.signatures | transpose k v | get 0.v
        mut p = {}
        mut r = []
        mut flags = []
        for i in $x {
            if ($i.parameter_name | is-empty) { continue }

            mut e = null
            let type = if ($i.syntax_shape? | default '' | str starts-with 'completable<') {
                $i.syntax_shape | str substring 12..<-1
                let e1 = nu -c $'do -i { ($i.custom_completion) } | to json' | from json
                $e = if ($e1 | describe | str starts-with 'table') {
                    $e1 | get value
                } else {
                    $e1
                }
            } else if $i.parameter_type == 'switch' {
                'bool'
            } else {
                $i.syntax_shape
            }
            let e = if ($e | is-empty) { {} } else { {enum: $e} }

            if $i.parameter_type != positional {
                $flags ++= [$i.parameter_name]
            }

            if not $i.is_optional { $r ++= [$i.parameter_name] }

            $p = $p | insert $i.parameter_name {
                type: $type
                description: $i.description
                ...$e
            }
        }
        {
            value: {
                type: object
                properties: $p
                required: $r
            }
            flags: $flags
        }
    }
    | select name description parameters
}

export def json-to-func [o tools] {
    $o
    | each {|x|
        let f = $x.function
        let c = $tools | where function.name == $f.name | get -i 0.flags
        mut cmd = [$f.name]
        for i in ($f.arguments | from json | transpose k v) {
            let flag = if $i.k in $c { $"--($i.k)" } else { '' }
            if ($i.v | describe) == bool {
                if $i.v {
                    $cmd ++= [$flag]
                }
            } else {
                $cmd ++= [$flag $i.v]
            }
        }
        $cmd | str join ' '
    }
}
