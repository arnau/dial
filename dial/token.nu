
# 1Password is dreadfully slow.
export def decrypt [reference: string] {
    ^op read $reference 
}

# Reads a value expecting eiher a plain token or a reference to be decrypted.
export def read [value: string] {
    let scheme = $value | try { url parse | get scheme } catch { null }

    match $scheme {
        # 1password reference
        "op" => (decrypt $value)
        # Assumed plain-text token
        _ => $value
    }
}
