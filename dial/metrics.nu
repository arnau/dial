# Calculations for metrics, guarding against empty collections.


# Average returning 0 if the sequence is empty.
export def avg [] {
    let sequence = $in

    if ($sequence | is-empty) { return 0 }

    $sequence | math avg
}

# Median returning 0 if the sequence is empty.
export def median [] {
    let sequence = $in

    if ($sequence | is-empty) { return 0 }

    $sequence | math median
}

# Maximum value returning 0 if the sequence is empty.
export def max [] {
    let sequence = $in

    if ($sequence | is-empty) { return 0 }

    $sequence | math max
}

# Minimum value returning 0 if the sequence is empty.
export def min [] {
    let sequence = $in

    if ($sequence | is-empty) { return 0 }

    $sequence | math min
}

# Minimum value returning 0 if the sequence is empty.
export def stddev [] {
    let sequence = $in

    if ($sequence | is-empty) { return 0 }

    $sequence | math stddev
}
