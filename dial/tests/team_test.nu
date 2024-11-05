use std assert
use ../config.nu *

const member_list = [
    {
        id: alice
        email: "alice@redonions.net"
        github_handle: alice-onion
        start_date: 2024-01-01
    }
    {
        id: bob
        email: "bob@redonions.net"
        github_handle: bob-onion
        start_date: 2024-01-01
    }
    {
        id: charly
        email: "charly@redonions.net"
        github_handle: charly-onion
        start_date: 2024-01-01
        end_date: 2024-04-11
    }
    {
        id: debra
        email: "debra@redonions.net"
        github_handle: debra-onion
        start_date: 2024-02-01
        end_date: 2024-09-23
    }
]


#[test]
def test_no_members [] {
    let expected = []
    let actual = team events member-list []
    assert equal $expected $actual
}


#[test]
def test_member_set [] {
    let expected = [
        { action: add, timestamp: 2024-01-01, member: alice }
        { action: add, timestamp: 2024-01-01, member: bob }
        { action: add, timestamp: 2024-01-01, member: charly }
        { action: add, timestamp: 2024-02-01, member: debra }
        { action: remove, timestamp: 2024-04-11, member: charly }
        { action: remove, timestamp: 2024-09-23, member: debra }
    ]

    let actual = team events member-list $member_list
    print "foo"
    assert equal $expected $actual
}

