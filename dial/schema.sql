-- Schema for the Dial database

-- Changesets, i.e. GitHub Pull Request
create table if not exists changeset (
    id                integer not null
    , source          text not null
    , repository      text not null
    , summary         text not null
    , creator         text not null
    , creation_date   datetime not null
    , resolution_date datetime not null
    , timeline_url    text not null

    , primary key (id, source, repository)
);


create table if not exists changeset_event (
    id             text not null
    , changeset_id integer not null
    , source       text not null
    , repository   text not null
    , timestamp    datetime not null
    , event        text not null
    , actor        text not null
    , url          text

    , primary key (id, source, repository, event)
);


-- Tickets, i.e. Jira Ticket
create table if not exists ticket (
    key               text not null
    , source          text not null
    , type            text not null
    , summary         text not null
    , parent          text
    , assignee        text not null
    , priority        integer
    , resolution      text
    , status          text not null
    , creation_date   datetime not null
    , resolution_date datetime not null
    
    , primary key (key, source)
);

-- Ticket status transition. E.g. change from 'in-progress' to 'done'.
create table if not exists ticket_status (
    id          integer not null
    , key       text not null
    , source    text not null
    , timestamp datetime not null
    , actor     text not null
    , start     text not null
    , end       text not null

    , primary key (id, key, source)
);
