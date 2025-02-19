use ../../config.nu *
export-env {
    ai-config-env-tools run_python_code {
        schema: {
            name: run_python_code,
            description: "This function executes Python code in the current working directory. It can be used to run scripts, modules, or any Python code snippet.",
            parameters: {
                type: object,
                properties: {
                    code: {
                        type: string,
                        description: "The Python code to execute. This can be a single line or multiple lines of code."
                    },
                    filename: {
                        type: string,
                        description: "(Optional) The filename to save the code if running from a file. If not provided, the code will be executed directly."
                    },
                    timeout: {
                        type: number,
                        description: "(Optional) Maximum time in seconds to wait for the code execution before timing out. Default is no timeout."
                    }
                },
                required: [
                    code
                ]
            }
        }
        handler: {|x, ctx|
            let f = if ($x.file_name? | is-empty) {
                mktemp --suffix .py
            } else {
                $x.file_name
            }
            $x.code | save -f $f
            let o = python $f
            if ($x.file_name? | is-empty) {
                rm -f $f
            }
            $o
        }
    }
}
