export-env {
    use integration/ollama.nu *
    use call.nu *
    use function.nu *
    $env.AI_CONFIG = {
        curl: (which curl | is-not-empty)
        finish_reason: xterm_grey30
        tool_calls: grey
        message_limit: 20
    }
}


export use integration/ollama.nu *
export use integration/local.nu *
export use call.nu *
