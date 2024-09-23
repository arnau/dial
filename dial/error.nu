# Convenience function for unspanned errors.
export def fail [msg: string] {
    error make --unspanned {msg: $msg}
}

# Attempts to read from an enviornment variable. Fails if not present.
export def try-env [env_name: string]: [nothing -> string] {
    try {
        $env | get $env_name
    } catch {
        fail $"Expected an environment variable named `($env_name)`"
    }
}
