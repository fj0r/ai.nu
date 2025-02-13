def is-sub-directory [parent] {
    $in | path expand | str starts-with ($parent | path expand)
}

use ../../config.nu *
export-env {
    ai-config-env-tools get_current_time {
        schema: {
            description: "This function retrieves the current date and time.",
            parameters: {
                type: object,
                properties: {
                    timezone: {
                        type: string,
                        description: "The timezone for which the current time is requested. If not provided, the default is UTC."
                    }
                },
                required: [

                ]
            }
        }
        handler: {|x, ctx| date now | format date '%F %A %H:%M:%S' }
    }

    ai-config-env-tools find_largest_subdirectory {
        schema: {
            description: "This function allows you to find the subdirectory that occupies the most space within a given directory. It can be useful for identifying large directories that may need to be cleaned up or managed.",
            parameters: {
                type: object,
                properties: {
                    directory_path: {
                        type: string,
                        description: "The path to the directory to search within"
                    },
                    include_hidden: {
                        type: boolean,
                        description: "Whether to include hidden subdirectories in the search",
                        default: false
                    },
                    max_depth: {
                        type: number,
                        description: "The maximum depth to search within the directory hierarchy. Set to -1 for no limit.",
                        default: -1
                    }
                },
                required: [
                    directory_path
                ]
            }
        },
        handler: {|x, ctx|
            mut args = [--output-json --full-paths]
            if not ($x.include_hidden? | default false) {
                $args ++= [--ignore_hidden]
            }
            let p = $x.directory_path | path expand
            sudo dust $p ...$args
        }
    }

    ai-config-env-tools delete_files {
        schema: {
            description: "This function allows you to delete multiple files by providing a list of file paths. It can be used to remove files from the file system.",
            parameters: {
                type: object,
                properties: {
                    file_paths: {
                        type: array,
                        description: "A list of file paths to be deleted",
                        items: {
                            type: string,
                            description: "The full path to a file"
                        }
                    }
                },
                required: [
                    file_paths
                ]
            }
        }
        handler: {|x, ctx|
            {||
                for f in $x.file_paths {
                    let d = $f | is-sub-directory $env.AI_CONFIG.permitted-write
                    rm -f $f
                    print $"(ansi 'xterm_salmon1')rm -f ($f)(ansi reset)"
                }
            }
            | do $ctx.ConfirmExec $'delete ($x.file_paths)?' true {|| }
        }
    }

    ai-config-env-tools read_file {
        schema: {
            description: "This function reads the content of a file from the specified path and returns the content as a string.",
            parameters: {
                type: object,
                properties: {
                    file_path: {
                        type: string,
                        description: "The absolute or relative path to the file."
                    }
                },
                required: [
                    file_path
                ]
            }
        }
        handler: {|x, ctx|
            open -r $x.file_path
        }
    }

    ai-config-env-tools write_file {
        schema: {
            description: "This function allows you to write content to a file. It can be used to create new files or append content to existing files.",
            parameters: {
                type: object,
                properties: {
                    file_path: {
                        type: string,
                        description: "The path to the file where the content will be written"
                    },
                    content: {
                        type: string,
                        description: "The content to be written to the file"
                    },
                    mode: {
                        type: string,
                        description: "The mode in which the file will be opened",
                        enum: [
                            w,
                            a
                        ]
                    }
                },
                required: [
                    file_path,
                    content,
                    mode
                ]
            }
        }
        handler: {|x, ctx|
            {||
                match $x.mode {
                    w => {
                        $x.content | save -f $x.file_path
                    }
                    a => {
                        $x.content | save -a $x.file_path
                    }
                }
            }
            | do $ctx.ConfirmExec $"Write ($x.file_path)" (not ($x.file_path | is-sub-directory $env.AI_CONFIG.permitted-write)) {||}
        }
    }

    ai-config-env-tools list_directory_files {
        schema: {
            description: "This function lists all files in a specified directory, including files in subdirectories. It can be used to explore the file structure of a directory and its subdirectories. If no directory is specified, it defaults to the current directory.",
            parameters: {
                type: object,
                properties: {
                    directory_path: {
                        type: string,
                        description: "The path to the directory to list files from"
                    },
                    include_subdirectories: {
                        type: boolean,
                        description: "Whether to include files from subdirectories",
                        default: true
                    },
                    file_types: {
                        type: array,
                        items: {
                            type: string
                        },
                        description: "A list of file extensions to filter by (e.g., ['txt', 'pdf'])",
                    }
                },
                required: [
                ]
            }
        }
        handler: {|x, ctx|
            if ($x.directory_path? | is-not-empty) {
                cd $x.directory_path
            }
            mut p = if ($x.include_subdirectories? | default true) {
                '**/*'
            } else {
                '*'
            }
            if ($x.file_types? | is-not-empty) {
                $p += $".{($x.file_types | str join ,)}"
            }
            glob $p --exclude [**/target/** **/.git/** */]
        }
    }
}
