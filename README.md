# Role Graph Views for PostgreSQL 16+

## Description

With the release of PostgreSQL v16.0 the role permission system
changed a great deal.  In particular, the CREATEROLE attribute
became secure enough to be considered a viable delegation
option to people who should not have superuser capabilities.

This pseudo-extension brings visbility into the chain of memberhsip
grants terminating at each role in the system.

See a [20 minute overview video](https://youtu.be/W3X_mB7wzTs) on my
[YouTube channel](https://www.youtube.com/channel/UCFf7Mj5i8QI1tAPgUTl63Pw)

## Value Proposition

This project provides four main areas of value to the PostgreSQL community:

1. The role_graph view itself, providing in-database insight into the web of role memberships and related permissions.
2. A commented example of Dynamic SQL that generates permanent views within the database.
3. A commented example of a Recursive Common Table Expression (rCTE)
4. An example of a psql-based test-driven script with output file regressions.

## Usage

Runs psql: use environment variables to configure, and also ensure psql
is reachable via PATH.  Note, it also uses a custom `.psqlrc` file.

`./install.bash`

Removes and reinstalls a schema named "rolegraph" and then executes
a pl/pgsql DO block to create three views within it:

- role_relationship (see `./test/details/` for examples)
- role_graph_detail
- role_graph (see `./test/expected/` for examples)

## Considerations

* The grant system of PostgreSQL does not permit cycles.
* Every row in pg_auth_members is a bi-directional graph edge.
  * Roles are nodes
* Every membership grant in the system can optionally be augmented with:
  - Admin
  - Set
  - Inherit
* If none of the options are present the grant is deemed "Empty"
  * While the system allows for this monitoring systems should
    and report when it does happen.
* The PostgreSQL role system did away with the concepts of users
  and groups a while back; this was a mistake.
  * Note, the terms exist in the grammar for continuity.
* The "cannot login" label is not used.
  * Groups, listed first, cannot login.
  * Users, listed last, have the login attribute.
  * Superusers, if present, separate the two.

## Example Output

```
 rolname |     administration     |        memberof_groups        | memberof_users |       member_groups       |         member_users
---------+------------------------+-------------------------------+----------------+---------------------------+------------------------------
 grp1    | by usr from superuser  | grp2 from superuser (s,i)     |                |                           | usr from superuser (s,i)
 grp2    |                        |                               |                | grp1 from superuser (s,i) | usr via grp1/superuser (s,i)
 usr     | of grp1 from superuser | grp1 from superuser (s,i)    +|                |                           |
         |                        | grp2 via grp1/superuser (s,i) |                |                           |
```

## Development

`./test.bash`

The environment must be configured for psql to connect to a freshly installed cluster as the boostrap superuser.

Potentially destructive test runner that creates (and removes) roles
from the cluster and then outputs role_graph view results into the `./test/output/`
directory. Those are `diff`'ed against the files in the `./test/expected/` directory.

Every psql script in the `./test/` directory will be executed, ordered
by name.  Two passes will be made over the file with psql variables set as such:

- `ctx=su, is_su=true, is_cr=false`

on the first pass and to the following on the second pass:

- `ctx=cr, is_su=false, is_cr=true`.

The script can thus do different things depending upon whether a role with
the CREATEROLE attribute is executing the commands, or a superuser is.

The roles that the scripts create must conform to a naming scheme.
Before running the script in "superuser" mode all roles following that naming
scheme will be dropped.  They are also dropped at the end of each script.  See the dynamic psql
script constructed in `test.bash` for details, and the `./lib/remove-roles.psql`
script for the actual removal command and the naming scheme.

On-the-fly reset can be accomplished by running the following command:

`PSQLRC=.psqlrc psql -q -f ./lib/remove-roles.psql -f ./lib/reset-globals.psql`

In addition to the following environment settings for on-the-fly configuration:

`PGDATABASE=postgres PATH="${PATH}:/usr/local/pgsql/bin" `

## Contact

Submit an issue or meet me in the community (Slack, Discord, pgsql-general)

## Copyright

David G. Johnston, 2023, All Rights Reserved

[My Homepage](https://david-g-johnston.com/)

## License

[The PostgreSQL License](LICENSE)

## Gratitude and Sustenance

<a href="https://www.buymeacoffee.com/davidgjohnston/role-graph-postgresql" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
