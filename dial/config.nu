# The dial config. Expects a `data/config.nu` file to exist.
#
# See the `data/config.example.nu`
export def main [] {
    open data/config.nuon
}

export def "team list" [] {
    main | get teams | get name
}

# The list of repos for the given team.
export def "team repos" [team: string@"team list"] {
    main | get teams | where name == $team | get 0.repos
}

# The list of members for the given team.
export def "team members" [team: string@"team list"] {
    main | get teams | where name == $team | get 0.members
}
