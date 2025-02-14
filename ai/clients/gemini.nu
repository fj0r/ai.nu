use openai.nu

export def --wrapped req [
    ...args
] {
    mut o = $in | default { messages: [] }
    $o | openai req ...$args

}
