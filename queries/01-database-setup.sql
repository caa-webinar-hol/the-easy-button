/*
=============================================================================
01 - Database & Role Setup
=============================================================================
Creates:
  - HOL_ROLE for running the demo
  - HOL_WH warehouse (XS, auto-suspend)
  - POC database and EASY_BUTTON_HOL schema
  - Grants ownership to HOL_ROLE
Uses IF NOT EXISTS to preserve existing objects.
=============================================================================
*/

USE ROLE ACCOUNTADMIN;

-- Create HOL role
CREATE ROLE IF NOT EXISTS HOL_ROLE
    COMMENT = 'Role for CKE + Snowflake Intelligence + Cortex Code HOL';

-- Grant role to current user
SET MY_USER = CURRENT_USER();
GRANT ROLE HOL_ROLE TO USER IDENTIFIER($MY_USER);

-- Create warehouse for HOL
CREATE WAREHOUSE IF NOT EXISTS HOL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for CKE + Snowflake Intelligence + Cortex Code HOL';

GRANT OWNERSHIP ON WAREHOUSE HOL_WH TO ROLE HOL_ROLE COPY CURRENT GRANTS;

-- Create database (owned by HOL_ROLE)
CREATE DATABASE IF NOT EXISTS POC
    COMMENT = 'Proof of Concept database for demos and HOLs';

GRANT OWNERSHIP ON DATABASE POC TO ROLE HOL_ROLE COPY CURRENT GRANTS;

-- Switch to HOL_ROLE to create schema (since HOL_ROLE now owns DB)
USE ROLE HOL_ROLE;
USE WAREHOUSE HOL_WH;

CREATE SCHEMA IF NOT EXISTS POC.EASY_BUTTON_HOL
    COMMENT = 'Schema for CKE + Snowflake Intelligence + Cortex Code HOL';

-- Use context
USE DATABASE POC;
USE SCHEMA EASY_BUTTON_HOL;

-- Verify
SELECT 
    CURRENT_ROLE() AS role,
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_DATABASE() AS database, 
    CURRENT_SCHEMA() AS schema;
