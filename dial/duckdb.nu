# DuckDB helpers
#
# DEPENDENCIES: duckdb


# Executes the given command against the given database.
#
# ```nu
# duckdb run "select * from 'foo.parquet'"
# duckdb run "copy tbl from 'foo.parquet'" mydb.duckdb
# ```
export def run [
    command: string  # The query to run.
    filename: string = "" # The filename of the DuckDB database to use.
    --bail # Stop after hitting an error.
] {
    let flags = [
        {flag: "-bail", value: $bail}
    ]

    let options = $flags | where value == true | get flag | str join ' '

    ^duckdb $options -jsonlines -c $command  $filename
    | lines
    | each { from json }
}

# Opens a file or set of files based on the file extension.
#
# Note that Duckdb is able to open CSV, Parquet and JSON by default.
# If you need to provide more details like the schema or separator for a CSV file, use `ddb run` instead:
#
# ```nushell
# ddb run "select * from read_csv('foo.csv', delim = '|', header = false, columns = {'id': 'bigint', name: 'varchar', 'date': 'date'}, dateformat = '%d/%m/%Y')"
# ```
export def "open" [glob: string] {
    ^duckdb -jsonlines -c $"select * from '($glob)'"
    | lines
    | each { from json }
}

# Saves the given data into the given filename.
#
# [{a: 1, b: 2}, {a: 3, b: 4}] | ddb save foo.parquet
export def save [
      filename: string
      --force (-f)
]: [table -> nothing] {
    if ($filename | str contains "'") {
        error make {msg: "The filename must not contain a single quote `'`."}
    }

    if ($filename | path exists) and (not $force) {
        error make {msg: "The filename must not exist."}
    }

    let path = ($filename | path parse)
    let format = match $path.extension {
        "jsonl" => "json"
        $e => $e
    }

  $in
  | to json
  | ^duckdb -c $"copy \(select * from read_json\('/dev/stdin'\)\) to '($filename)' \(format '($format)'\)"
}
