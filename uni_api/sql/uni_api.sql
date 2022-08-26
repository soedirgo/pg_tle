--  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
--  
--  Licensed under the Apache License, Version 2.0 (the "License").
--  You may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--  
--      http://www.apache.org/licenses/LICENSE-2.0
--  
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

-- Expect password to go through since we haven't enabled the feature
CREATE ROLE testuser with password 'pass';
-- Test 'on' / 'off' / 'require'
ALTER SYSTEM SET bc.enable_password_check = 'off';
SELECT pg_reload_conf();
ALTER ROLE testuser with password 'pass';
ALTER SYSTEM SET bc.enable_password_check = 'on';
SELECT pg_reload_conf();
-- Do not expect an error
ALTER ROLE testuser with password 'pass';
CREATE EXTENSION uni_api;
-- Do not expect an error
ALTER ROLE testuser with password 'pass';
ALTER SYSTEM SET bc.enable_password_check = 'require';
SELECT pg_reload_conf();
-- Expect an error for require if no entries are present
ALTER ROLE testuser with password 'pass';
-- Insert a value into the feature table
CREATE OR REPLACE FUNCTION password_check_length_greater_than_8(username text, shadow_pass text, password_types bc.password_types, validuntil_time TimestampTz,validuntil_null boolean) RETURNS void AS
$$
BEGIN             
if length(shadow_pass) < 8 then
  RAISE EXCEPTION 'Passwords needs to be longer than 8';
end if;
END;                      
$$                                                
LANGUAGE PLPGSQL;

SELECT bc.bc_feature_info_sql_insert('password_check_length_greater_than_8', 'passcheck');
-- Expect failure since pass is shorter than 8
ALTER ROLE testuser with password 'pass';
ALTER ROLE testuser with password 'passwords';
CREATE OR REPLACE FUNCTION password_check_only_nums(username text, shadow_pass text, password_types bc.password_types, validuntil_time TimestampTz,validuntil_null boolean) RETURNS void AS
$$
DECLARE x NUMERIC;
BEGIN
x = shadow_pass::NUMERIC;

EXCEPTION WHEN others THEN
RAISE EXCEPTION 'Passwords can only have numbers';
END;
$$ 
LANGUAGE PLPGSQL;
SELECT bc.bc_feature_info_sql_insert('password_check_only_nums', 'passcheck');
-- Test both functions are called
ALTER ROLE testuser with password 'passwords';
ALTER ROLE testuser with password '123456789';
INSERT INTO bc.feature_info VALUES ('passcheck', '', 'password_check_only_nums', '');
-- Expect to fail cause no schema qualified function found
ALTER ROLE testuser with password '123456789';
TRUNCATE bc.feature_info;
INSERT INTO bc.feature_info VALUES ('passcheck', 'public', 'test_foo;select foo()', '');
ALTER ROLE testuser with password '123456789';