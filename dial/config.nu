# The dial config. Expects a `data/config.nu` file to exist.
#
# See the `data/config.example.nu`
export def main [] {
    open data/config.nuon
}

export def "team list" [] {
    main | get teams
}

export def "team list names" [] {
    team list | get name
}

# The list of organisations for the given team.
export def "team orgs" [team: string@"team list names"] {
    team list | where name == $team | get 0.orgs
}

# The list of repos for the given team.
export def "team repos" [team: string@"team list names"] {
    team list | where name == $team | get 0.repos
}

# The list of members for the given team.
export def "team members" [team: string@"team list names"] {
    team list | where name == $team | get 0.members
}
