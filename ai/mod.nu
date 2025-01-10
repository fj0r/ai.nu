export-env {
    use ollama.nu *
    use openai.nu *
    use function.nu *
    $env.OPENAI_HTTP_CURL = true
}

export use ollama.nu *
export use openai.nu *
