use ../../config.nu *
export-env {
    ai-config-env-tools git {
        context: {
        }
        schema: {
            description: "Execute Git commands. It takes a list of Git command arguments to perform various Git operations such as commit, push, pull, etc.",
            parameters: {
                type: object,
                properties: {
                    args: {
                        type: array,
                        description: "A list of Git command arguments",
                        items: {
                            type: string,
                            description: "An individual Git command argument"
                        }
                    }
                },
                required: [
                    args
                ]
            },
        }
        handler: {|x, ctx|
            let x = if ($x | describe -d).type == 'list' {
                $x
            } else {
                if ($x.args | describe -d).type == 'list' {
                    $x.args
                } else {
                    [$x.args]
                }
            }
            git ...$x
        }
    }
}
