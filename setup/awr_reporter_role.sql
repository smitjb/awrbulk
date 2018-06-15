--
-- Define a role with the required privileges to run the awr bulk utility.
--
-- Producing AWR reports only requires execute on DBMS_WORKLOAD_REPOSITORY.
-- the other privileges are necessary for defining snapshot ranges
-- and locating other database's snapshots.
--
-- Must run as SYS
--
-- =======================================================================
create role awr_reporter;

GRANT SELECT ON SYS.V_$DATABASE TO awr_reporter;
GRANT SELECT ON SYS.V_$INSTANCE TO awr_reporter;
GRANT EXECUTE ON SYS.DBMS_WORKLOAD_REPOSITORY TO awr_reporter;
GRANT SELECT ON SYS.DBA_HIST_DATABASE_INSTANCE TO awr_reporter;
GRANT SELECT ON SYS.DBA_HIST_SNAPSHOT TO awr_reporter;
GRANT SELECT ON SYS.WRM$_DATABASE_INSTANCE TO awr_reporter;
GRANT SELECT ON SYS.WRM$_SNAPSHOT TO awr_reporter;
