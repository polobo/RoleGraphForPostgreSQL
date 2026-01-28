# AGENTS.md

## MCP Integration

**Before starting any task or executing anything related to SQL prompt you MUST:**
1. Call the MCP tool `get_shared_agent_rules`
2. Follow those rules as canonical guidance
3. Apply repo-specific patterns documented below

## Repository Purpose
This project provides visibility and analysis tools for PostgreSQL 16+ role permission systems through database views that map role membership relationships. The primary deliverable is the `role_graph` view - a recursive query that visualizes the complete chain of membership grants, administrative relationships, and privilege inheritance across all roles in a PostgreSQL cluster.

**Core Components:**
- **Database Views** (`lib/install-schema-and-views.psql`): Dynamic SQL that creates three interconnected views within the `rolegraph` schema to expose role relationships
- **Test Framework** (`test.bash`): Regression-based test suite with 9 scenarios demonstrating role membership patterns under both superuser and CREATEROLE contexts
- **Documentation** (`doc/*.mmd`): Mermaid diagrams illustrating complex role hierarchy examples
- **Output Examples** (`test/expected/*.txt`): Reference outputs showing how role graphs appear for various organizational structures

**Key Value:**
1. In-database insight into PostgreSQL 16's enhanced CREATEROLE delegation system
2. Commented examples of recursive CTEs and dynamic SQL view generation
3. psql-based test-driven development pattern with output file regression testing
4. Real-world scenarios of role administration (service advisors, managers, inherited privileges)

**Target Users:** Database administrators managing complex role hierarchies, particularly those leveraging PostgreSQL 16's secure CREATEROLE delegation to non-superusers.