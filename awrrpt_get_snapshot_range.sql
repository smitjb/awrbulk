define database_name='&1'
define last_snapshot_id='&2'

SELECT MIN(wss.SNAP_ID),
    MAX(WSS.SNAP_ID),
    wss.DBID,
    wdi.INSTANCE_NAME,
    wdi.DB_NAME,
    wss.INSTANCE_NUMBER,
    wdi.VERSION,
    wdi.HOST_NAME
FROM SYS.WRM$_SNAPSHOT wss
inner join SYS.WRM$_DATABASE_INSTANCE wdi
on wss.dbid=wdi.dbid
and wss.instance_number=wdi.instance_number
and wss.startup_time = wdi.startup_time
where db_name='&database_name'
AND WSS.SNAP_ID >= &last_snapshot_id
GROUP BY   wss.DBID,
  wss.INSTANCE_NUMBER,
  wdi.VERSION,
  wdi.DB_NAME,
  wdi.INSTANCE_NAME,
  wdi.HOST_NAME;
  