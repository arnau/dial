# HTTP helpers, extending std http


# Expects an input from a raw Link http header.
#
# This is a rather naive parser for IETF RFC 8288 Web Linking values.
#
# ## Example
#
# ```nu
# '<https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=2>; rel="next", <https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=42>; rel="last"' | http from link-header
# ```
export def "from link-header" [] {
    $in
    | split row ","
    | each { $in | str trim | parse "<{url}>; rel=\"{rel}\"" }
    | flatten
}

# Input expected to be a valid http response record as per `http get`.
export def "header pick" [header_name: string] {
    let response = $in

    $response.headers.response
    | where name == $header_name
    | if ($in | is-not-empty) { get 0.value } else { null }
}

# Attempts to find a link by rel (RFC 8288).
#
# input: A valid http response
#
# ## Example
#
# ```nu
# http get https://api.github.com/search/issues | http link "next"
# ```
export def link [rel: string] {
    let raw = $in | header pick "link"

    if ($raw | is-empty) { return null }
    
    $raw
    | from link-header
    | where rel == $rel
    | if ($in | is-not-empty) { get 0.url } else { null }
}


# Attempts to find the next URL provided via Web Linking (RFC 8288).
#
# input: A valid http response
#
# ## Example
#
# ```nu
# http get https://api.github.com/search/issues | http next
# ```
export def next [] {
    $in | link next
}

# Attempts to find the last URL provided via Web Linking (RFC 8288).
#
# input: A valid http response
#
# ## Example
#
# ```nu
# http get https://api.github.com/search/issues | http last
# ```
export def last [] {
    $in | link last
}

# Attempts to find the first URL provided via Web Linking (RFC 8288).
#
# input: A valid http response
#
# ## Example
#
# ```nu
# http get https://api.github.com/search/issues | http first
# ```
export def first [] {
    $in | link first
}

# Attempts to find the previous URL provided via Web Linking (RFC 8288).
#
# input: A valid http response
#
# ## Example
#
# ```nu
# http get https://api.github.com/search/issues | http prev
# ```
export def prev [] {
    $in | link prev
}
