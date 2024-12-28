export def 'json-to-string' [json] {
    $json | to json -r | str replace '"' '\"' -a
}

export def block-edit [
    temp
    --context: record
] {
    let content = $in
    let tf = mktemp -t $temp
    $content | save -f $tf
    if ($context | is-not-empty) {
        $env.AI_EDITOR_CONTEXT = $context | upsert file $tf | to nuon
    }
    ^$env.EDITOR $tf
    let c = open $tf --raw
    rm -f $tf
    $c
}

export def render [scope: record] {
    let tmpl = $in
    $scope
    | transpose k v
    | reduce -f $tmpl {|i,a|
        let k = if $i.k == '_' { '' } else { $i.k }
        $a | str replace --all $"{{($k)}}" ($i.v | to text)
    }
}
