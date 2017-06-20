select output from table(dbms_workload_repository.awr_report_html( :dbid,
                                                      :inst_num,
                                                      :bid, :eid,
                                                      :rpt_options ));


