export-env {
    use ollama.nu *
    use openai.nu *
    use function.nu *
    $env.OPENAI_CONFIG = {
        curl: (which curl | is-not-empty)
        finish_reason: xterm_grey30
        tool_calls: grey
    }
}

export use ollama.nu *
export use local.nu *
export use openai.nu *
