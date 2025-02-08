def is-sub-directory [parent] {
    $in | path expand | str starts-with ($parent | path expand)
}

export-env {
    $env.AI_TOOLS = $env.AI_TOOLS | merge {
        get_current_time: {
            schema: {
                description: "This function retrieves the current date and time.",
                parameters: {
                    type: "object",
                    properties: {
                        timezone: {
                            type: "string",
                            description: "The timezone for which the current time is requested. If not provided, the default is UTC."
                        }
                    },
                    required: []
                }
            }
            handler: {|x, config| date now | format date '%F %H:%M:%S' }
        }
        find_largest_subdirectory: {
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
            handler: {|x, config|
                mut args = [--output-json --full-paths]
                if not ($x.include_hidden? | default false) {
                    $args ++= [--ignore_hidden]
                }
                let p = $x.directory_path | path expand
                sudo dust $p ...$args
            }
        }
        delete_files: {
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
            handler: {|x, config|
                for f in $x.file_paths {
                    let x = $f | is-sub-directory $env.AI_CONFIG.permitted-write
                    let c = if $x {
                        rm -f $f
                        'xterm_salmon1'
                    } else {
                        'xterm_lightgoldenrod1'
                    }
                    print $"(ansi $c)rm -f ($f)(ansi reset)"
                }
            }
        }
    }
}
