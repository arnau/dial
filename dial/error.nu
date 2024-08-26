# Convenience function for unspanned errors.
export def fail [msg: string] {
    error make --unspanned {msg: $msg}
}
