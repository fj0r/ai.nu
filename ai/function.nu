use completion.nu *

export def func-list [...fns:string@cmpl-nu-function] {
    scope commands
    | where name in $fns
    | each { func-to-json $in }
    | each {|x| {type: function, function: $x} }
}

export def func-to-json [fn] {
    $fn
    | insert parameters {|x|
        let x = $x.signatures | transpose k v | get 0.v
        mut p = {}
        mut r = []
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

            let name = if $i.parameter_type == positional {
                ''
            } else {
                $"--($i.parameter_name)"
            }

            if not $i.is_optional { $r ++= [$i.parameter_name] }

            $p = $p | insert $i.parameter_name {
                type: $type
                name: $name
                description: $i.description
                ...$e
            }
        }
        {
            type: object
            properties: $p
            required: $r
        }
    }
    | select name description parameters
}

export def json-to-func [o tools] {
    $o
    | each {|x|
        let f = $x.function
        let c = $tools | where function.name == $f.name | get -i 0.function.parameters.properties
        mut cmd = [$f.name]
        for i in ($f.arguments | from json | transpose k v) {
            if ($i.v | describe) == bool {
                if $i.v {
                    $cmd ++= [($c | get $i.k | get name)]
                }
            } else {
                $cmd ++= [($c | get $i.k | get name) $i.v]
            }
        }
        $cmd | str join ' '
    }
}
