export def 'json-to-string' [json] {
    $json | to json -r | str replace --all '"' '\"'
}

export def block-edit [
    temp
    --context: record
] {
    let content = $in
    let d = mktemp -d -t $temp
    let tf = [$d ai.md] | path join
    $content | save -f $tf
    if ($context | is-not-empty) {
        $env.AI_EDITOR_CONTEXT = $context | upsert file $tf | to nuon
    }
    cd $d
    ^$env.EDITOR $tf
    let c = open $tf --raw
    rm -f $tf
    $c
}

export def render [vars: record] {
    let tmpl = $in
    let v = $tmpl
    | parse -r '(?<!{){{(?<v>[^{}]*?)}}(?!})'
    | get v
    | uniq

    $v
    | reduce -f $tmpl {|i, a|
        let k = $i | str trim
        let k = if ($k | is-empty) { '_' } else { $k }
        $a | str replace --all $"{{($i)}}" ($vars | get $k | to text)
    }
}
