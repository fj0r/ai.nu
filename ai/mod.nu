export-env {
    use integration/ollama.nu *
    use openai.nu *
    use function.nu *
    $env.OPENAI_CONFIG = {
        curl: (which curl | is-not-empty)
        finish_reason: xterm_grey30
        tool_calls: grey
    }
}


export use integration/ollama.nu *
export use integration/local.nu *
export use openai.nu *
