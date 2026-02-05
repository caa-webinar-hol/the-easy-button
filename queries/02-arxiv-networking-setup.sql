/*
=============================================================================
02 - arXiv Networking Setup
=============================================================================
Creates Network Rule and External Access Integration for arXiv API.
No API key required - arXiv is completely free and public.

Note: Network rules and EAIs must be created by ACCOUNTADMIN,
      then usage is granted to HOL_ROLE.
=============================================================================
*/

-- First, as HOL_ROLE (owner), grant ACCOUNTADMIN privileges to create objects
USE ROLE HOL_ROLE;
GRANT USAGE ON DATABASE POC TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA POC.EASY_BUTTON_HOL TO ROLE ACCOUNTADMIN;
GRANT CREATE NETWORK RULE ON SCHEMA POC.EASY_BUTTON_HOL TO ROLE ACCOUNTADMIN;

-- Now switch to ACCOUNTADMIN to create networking objects
USE ROLE ACCOUNTADMIN;
USE DATABASE POC;
USE SCHEMA EASY_BUTTON_HOL;

-- Network rule for arXiv API and PDF downloads
CREATE OR REPLACE NETWORK RULE arxiv_network_rule
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST = ('export.arxiv.org:443', 'arxiv.org:443');

-- Transfer ownership to HOL_ROLE
GRANT OWNERSHIP ON NETWORK RULE arxiv_network_rule TO ROLE HOL_ROLE COPY CURRENT GRANTS;

-- External Access Integration (no secrets needed - arXiv is public)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION arxiv_integration
    ALLOWED_NETWORK_RULES = (POC.EASY_BUTTON_HOL.arxiv_network_rule)
    ENABLED = TRUE;

-- Grant usage on EAI to HOL_ROLE (EAI ownership stays with ACCOUNTADMIN)
GRANT USAGE ON INTEGRATION arxiv_integration TO ROLE HOL_ROLE;

-- Switch to HOL_ROLE for verification
USE ROLE HOL_ROLE;
USE WAREHOUSE HOL_WH;

-- Verify
SHOW NETWORK RULES LIKE 'arxiv%';
SHOW INTEGRATIONS LIKE 'arxiv%';
