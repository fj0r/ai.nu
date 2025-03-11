use ../../config.nu *
export-env {
    ai-config-env-tools copy_to_clipboard {
        context: {
        }
        schema: {
            description: "Copy specified text content to the system clipboard, supports plain text format"
            parameters: {
                properties: {
                    text: {
                        type: string,
                        description: "Text content to be copied to the clipboard"
                    }
                },
                required: [
                    text
                ]
            }
        }
        handler: {|x, ctx|
            let x = if ($x | describe -d).type == 'list' { $x } else { $x.text }
            $x | wl-copy
        }
    }
    ai-config-env-tools read_clipboard {
        context: {
        }
        schema: {
            description: "Retrieve the contents of the clipboard. It can be used to access text, images, or other data that has been copied or cut to the clipboard.",
            parameters: {
                type: object,
                properties: {}
                required: []
            }
        }
        handler: {|x, ctx|
            wl-paste
        }
    }
}
