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
                        type: string,
                        description: "Complete git command arguments as a single string, e.g. \"commit -am 'fix: something'\", \"diff HEAD~1\", \"log --oneline -5\""
                    }
                },
                required: [
                    args
                ]
            },
        }
        handler: {|x, ctx|
            # normalize to a single shell command string
            let s = if ($x | describe) == 'string' {
                $x
            } else {
                let a = if ($x | describe -d).type == 'list' { $x } else { $x.args? | default [$x] }
                let a = if ($a | describe) == 'string' {
                    $a
                } else if (($a | length) == 1) and (($a | first) =~ ' ') {
                    # model packed the whole command into one element
                    $a | first
                } else {
                    # legacy: individual args, shell-quote each
                    $a | each {|i|
                        $"'($i | str replace --all "'" "'\\''")'"
                    } | str join ' '
                }
                $a
            }
            # strict: model must provide a single complete command string;
            # errors are fed back to the LLM via the tool-message retry loop
            bash -c $"git ($s)"
        }
    }
}
