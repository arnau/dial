use error.nu *
use duckdb.nu

def "db run" [sql: string] {
    let location = try-env DIAL_DB

    duckdb run $sql $location
}


# Initialises a new storage at the location indicated by the `DIAL_DB`.
export def --env init [] {
    let location = if ($env.DIAL_DB? | is-empty) { "data/dial.db" } else { $env.DIAL_DB? }

    if ($location | path exists) { return }

    # TODO: Assumes context.
    db run (open dial/schema.sql)        
}

def tables [] {
    let location = if ($env.DIAL_DB? | is-empty) { "data/dial.db" } else { $env.DIAL_DB? }

    duckdb run "select table_name from information_schema.tables where table_schema = 'main' and table_type = 'BASE TABLE';" $location
    | get table_name
}

# Attempts to save the given data into the Dial storage.
export def save [table_name: string@"tables"] {
    let location = if ($env.DIAL_DB? | is-empty) { "data/dial.db" } else { $env.DIAL_DB? }

    if not ($location | path exists) {
        fail $"The database in ($location) does not exist. Please run `dial storage init`"
    }

    $in
    | duckdb upsert $table_name $location        
}

export def query [sql: string] {
    let location = if ($env.DIAL_DB? | is-empty) { "data/dial.db" } else { $env.DIAL_DB? }

    if not ($location | path exists) {
        fail $"The database in ($location) does not exist. Please run `dial storage init`"
    }

    duckdb run $sql $location
}
