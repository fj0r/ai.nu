def cmpl-server [] {
    [ollama llama.cpp tgi]
}

export def --wrapped run-llm-with [
    server:string@cmpl-server
    --name:string
    --proxy:string
    --port:int=11434
    --world:string
    --cuda
    --model:string
    --dry-run
    --envs:record
    ...args:string
] {
    mut dargs = []

    let name = if ($name | is-empty) {
        $server
    } else {
        $name
    }

    let ctx = match $server {
        'llama.cpp' => {
            let image = 'ghcr.io/ggerganov/llama.cpp:server'
            let image = if $cuda { $"($image)-cuda" } else { $image }
            mut args = [--port 8080]
            if ($model | is-not-empty) {
                $args ++= [-m $model]
            }
            {
                image: $image
                args: $args
                port: 8080
                cache: $"($env.HOME)/.cache/llama.cpp:/root/.cache/llama.cpp"
            }
        }
        'ollama' => {
            {
                image: 'ollama/ollama'
                args: []
                port: 11434
                cache: $"($env.HOME)/.ollama:/root/.ollama"
            }
        }
        'tgi' => {
            mut args = []
            if ($model | is-not-empty) {
                $args ++= [--model-id $model]
            }
            {
                image: 'ghcr.io/huggingface/text-generation-inference:latest'
                args: $args
                port: 80
                cache: $"($env.HOME)/.cache/huggingface:/data"
            }
        }

    }

    $dargs ++= [--name $name -d]

    let port = port $port
    print $"(ansi grey)listen ($port)(ansi reset)"
    $dargs ++= [-v $ctx.cache -p $"($port):($ctx.port)"]

    if ($proxy | is-not-empty) {
        $dargs ++= [
            -e $"http_proxy=($proxy)"
            -e $"https_proxy=($proxy)"
        ]
    }
    if ($envs | is-not-empty) {
        $dargs ++= $envs | items {|k, v| [-e $'($k)="($v)"'] } | flatten
    }
    if ($world | is-not-empty) {
        $dargs ++= [-v $"($world):/world"]
    }
    if $cuda {
        $dargs ++= [--gpus all]
    }
    if $name in (^$env.CONTCTL ps -a | from ssv -a | get NAMES) {
        ^$env.CONTCTL rm -f $name
    }

    if $dry_run {
        print ([docker run ...$dargs $ctx.image ...$ctx.args ...$args] | str join ' ')
    } else {
        ^$env.CONTCTL run ...$dargs $ctx.image ...$ctx.args ...$args
    }
}
