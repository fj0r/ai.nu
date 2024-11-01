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

export def 'json-to-string' [json] {
    $json | to json -r | str replace '"' '\"' -a
}

export def block-edit [temp] {
    let content = $in
    let tf = mktemp -t $temp
    $content | save -f $tf
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
        $a | str replace --all $"{($k)}" ($i.v | into string)
    }
}
