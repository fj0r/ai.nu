use ../../config.nu *
export-env {
    ai-config-env-tools git {
        context: {
        }
        schema: {
            description: "This function allows you to execute Git commands. It takes a list of Git command arguments to perform various Git operations such as commit, push, pull, etc.",
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
            git ...$x
        }
    }
}
