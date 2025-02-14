use openai.nu

export def req [
    --role(-r): string = 'user'
    --image(-i): string
    --audio(-a): string
    --tool-calls: string
    --tool-call-id: string
    --functions(-f): list<any>
    --model(-m): string
    --temperature(-t): number = 0.5
    --stream
    message?: string
] {
    mut o = $in | default { messages: [] }
    let functions = [
        ...($functions | default [])
        {google_search: {}}
    ]
    (
        $o | openai req
        --role $role
        --image $image
        --audio $audio
        --tool-calls $tool_calls
        --tool-call-id $tool_call_id
        --functions $functions
        --model $model
        --temperature $temperature
        --stream=$stream
        $message
    )

}
