--
-- Create a user to run the awrbulk utility
--
-- ===========================================================================
create user awr_user identified by awr_user;

grant create session to awr_user;

grant awr_reporter to awr_user;
