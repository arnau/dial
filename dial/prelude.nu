use duckdb.nu
use error.nu *

alias save-file = save
alias open-file = open


# Use `date to-weeknumber`.
def to-weeknumber [] {
    $in | format date "%V" | into int
}

# Convert text or datetime into an ISO weeknumber.
#
# ```nu
# "2024-08-05" | date to-weeknumber #=> 32
# ```
export def "date to-weeknumber" []: [string -> int, datetime -> int, list<string> -> list<int>, int -> int, list<int> -> list<int>] {
    let input = $in

    match ($input | describe) {
        "string" | "list<string>" => {
            $input | into datetime | to-weeknumber
        },
        "int" | "list<int>" => {
            $input | into datetime | to-weeknumber
        },
        "date" => {
            $input | to-weeknumber
        },
    }
}


export def "into iso-datestamp" []: [datetime -> string] {
    $in | format date "%F"
}

export def "into iso-timestamp" []: [datetime -> string] {
    $in | format date "%+"
}

export def "duration days" []: [duration -> int] {
    $in
    | into int
    | $in / 1_000_000_000
    | $in / 86_400
}

# Takes a raw number of days and casts it as a duration rounded to hours.
export def "duration from days" []: [int -> duration, float -> duration] {
    $in * 24
    | into int
    | into duration -u hr
}

export def "date weekday" [] {
    $in
    | format date "%u"
    | into int
}


# Calculates the number of working days between two datese, excluding weekends.
export def weekdays [start_date: datetime, end_date: datetime] {
    if ($end_date < $start_date) { fail "The end date must happen after the start date." }

    let days = (($end_date - $start_date) + 1day) | duration days
    let full_weeks = $days // 7
    # number of weekdays in the full weeks
    let weekdays_in_full_weeks = $full_weeks * 5
    # number of weekdays in the partial weeks
    let remaining_days = $days mod 7
    # number of weekend days in the remaining partial weeks
    mut weekend_days = 0
    let start_weekday = $start_date | date weekday
    mut end_weekday = $end_date | date weekday

    if ($days > ($full_weeks * 7)) {
        if ($end_weekday < $start_weekday) {
            $end_weekday += 7
        }

        if ($start_weekday <= 6) {
            if ($end_weekday >= 7) {
                # saturday and sunday exist in the remainder
                $weekend_days += 2
            } else if ($end_weekday >= 6) {
                # saturday exist in the remainder
                $weekend_days += 1
            }
        } else if ($start_weekday <= 7 and $end_weekday >= 7) {
            # sunday exists in the remainder
            $weekend_days += 1
        }
    }

    mut weekdays = $weekdays_in_full_weeks + $remaining_days - $weekend_days

    # When start and end are within the same weekend maths don't add up.
    if ($weekdays < 0) { $weekdays = 0 }

    $weekdays | duration from days
}


# A wrapper for the std open to bring opening parquet files into scope.
export def open [
    --raw (-r)
    --help (-h)
    ...files
] {
    if $help {
        open-file --help
    }

    if $raw {
        open-file --raw ...$files
    }

    let parquet_files = $files | where { path parse | get extension | $in == "parquet" }
    let other_files = $files | where { path parse | get extension | $in != "parquet" }

    interleave { open-file ...$other_files } { $parquet_files
        | par-each {|file| duckdb open $file }
        | flatten
    }
}
