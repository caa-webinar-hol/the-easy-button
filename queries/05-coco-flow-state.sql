-- =============================================================================
-- Easy Button HOL: arXiv Papers Analysis Pipeline
-- End-to-end workflow for document analysis, Cortex Search, and Agent creation
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1: Set up HOL context
-- -----------------------------------------------------------------------------
USE ROLE HOL_ROLE;
USE WAREHOUSE HOL_WH;
USE DATABASE POC;
USE SCHEMA EASY_BUTTON_HOL;

-- -----------------------------------------------------------------------------
-- STEP 2: Explore the data - List files in stage
-- -----------------------------------------------------------------------------
SELECT RELATIVE_PATH, SIZE, LAST_MODIFIED 
FROM DIRECTORY(@ARXIV_PAPERS_STAGE) 
ORDER BY RELATIVE_PATH;

-- Count total files
SELECT COUNT(*) AS file_count FROM DIRECTORY(@ARXIV_PAPERS_STAGE);

-- -----------------------------------------------------------------------------
-- STEP 3: Explore metadata table
-- -----------------------------------------------------------------------------
SELECT * FROM ARXIV_PAPERS_METADATA LIMIT 5;

-- Count metadata records
SELECT COUNT(*) AS metadata_count FROM ARXIV_PAPERS_METADATA;

-- Check category distribution
SELECT PRIMARY_CATEGORY, COUNT(*) AS cnt 
FROM ARXIV_PAPERS_METADATA 
GROUP BY PRIMARY_CATEGORY;

-- View table structure
DESCRIBE TABLE ARXIV_PAPERS_METADATA;

-- -----------------------------------------------------------------------------
-- STEP 4: Test AI_PARSE_DOCUMENT on sample PDFs
-- These are the 3 papers loaded by: CALL load_arxiv_papers('RAG', 'cs.CL', 3)
-- -----------------------------------------------------------------------------
-- Parse first sample PDF (Biomedical Retrieval paper)
SELECT 
    '2602.04731_2026-02-04_Khattab_Corbeil_Kora_etal_cs.CL.pdf' AS filename,
    AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04731_2026-02-04_Khattab_Corbeil_Kora_etal_cs.CL.pdf'),
        {'mode': 'LAYOUT'}
    ) AS parsed_content;

-- Parse second sample PDF (LinGO Framework paper)
SELECT 
    '2602.04693_2026-02-04_Zhang_Bertaglia_cs.CL.pdf' AS filename,
    AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04693_2026-02-04_Zhang_Bertaglia_cs.CL.pdf'),
        {'mode': 'LAYOUT'}
    ) AS parsed_content;

-- Parse third sample PDF (Information Retrieval paper)
SELECT 
    '2602.04579_2026-02-04_Khattab_Bauer_Heine_etal_cs.IR.pdf' AS filename,
    AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04579_2026-02-04_Khattab_Bauer_Heine_etal_cs.IR.pdf'),
        {'mode': 'LAYOUT'}
    ) AS parsed_content;

-- Check parsed document structure
SELECT 
    OBJECT_KEYS(AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04731_2026-02-04_Khattab_Corbeil_Kora_etal_cs.CL.pdf'),
        {'mode': 'LAYOUT'}
    )) AS parsed_keys;

-- Check content length
SELECT 
    LENGTH(AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04731_2026-02-04_Khattab_Corbeil_Kora_etal_cs.CL.pdf'),
        {'mode': 'LAYOUT'}
    ):content::STRING) AS content_length;

-- Check metadata (page count)
SELECT 
    AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', '2602.04731_2026-02-04_Khattab_Corbeil_Kora_etal_cs.CL.pdf'),
        {'mode': 'LAYOUT'}
    ):metadata AS parsed_metadata;

-- -----------------------------------------------------------------------------
-- STEP 5: Create the parsed documents base table
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARXIV_PAPERS_PARSED AS
SELECT 
    m.PAPER_ID,
    m.TITLE,
    m.FIRST_AUTHOR,
    m.AUTHORS,
    m.ABSTRACT,
    m.PRIMARY_CATEGORY,
    m.CATEGORIES,
    m.PUBLISHED_DATE,
    parsed:metadata:pageCount::INT AS PAGE_COUNT,
    parsed:content::VARCHAR AS FULL_TEXT,
    m.FILENAME,
    m.PDF_URL
FROM ARXIV_PAPERS_METADATA m,
LATERAL (
    SELECT AI_PARSE_DOCUMENT(
        TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', m.FILENAME),
        {'mode': 'LAYOUT'}
    ) AS parsed
);

-- Verify the parsed table
SELECT 
    PAPER_ID, 
    TITLE, 
    FIRST_AUTHOR, 
    PRIMARY_CATEGORY, 
    PAGE_COUNT, 
    LENGTH(FULL_TEXT) AS TEXT_LENGTH
FROM ARXIV_PAPERS_PARSED;

-- -----------------------------------------------------------------------------
-- STEP 6: Create Cortex Search Service
-- -----------------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE ARXIV_PAPERS_SEARCH_SERVICE
ON FULL_TEXT
ATTRIBUTES PRIMARY_CATEGORY, FIRST_AUTHOR, PUBLISHED_DATE
WAREHOUSE = HOL_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        PAPER_ID,
        TITLE,
        FIRST_AUTHOR,
        ABSTRACT,
        PRIMARY_CATEGORY,
        PUBLISHED_DATE,
        FULL_TEXT,
        PDF_URL
    FROM ARXIV_PAPERS_PARSED
);

-- Verify the search service
SHOW CORTEX SEARCH SERVICES LIKE 'ARXIV_PAPERS_SEARCH_SERVICE';

-- -----------------------------------------------------------------------------
-- STEP 7: Test Cortex Search Service
-- -----------------------------------------------------------------------------
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'POC.EASY_BUTTON_HOL.ARXIV_PAPERS_SEARCH_SERVICE',
        '{
            "query": "RAG optimization techniques for better retrieval performance",
            "columns": ["PAPER_ID", "TITLE", "FIRST_AUTHOR", "PRIMARY_CATEGORY"],
            "limit": 5
        }'
    )
) AS results;

-- -----------------------------------------------------------------------------
-- STEP 8: Create Cortex Agent with Search Tool
-- -----------------------------------------------------------------------------
CREATE OR REPLACE AGENT POC.EASY_BUTTON_HOL.ARXIV_RESEARCH_AGENT
  COMMENT = 'Research assistant for arXiv papers on RAG and AI'
  PROFILE = '{"display_name": "arXiv Research Assistant"}'
  FROM SPECIFICATION $$
  {
    "models": {
      "orchestration": "claude-4-sonnet"
    },
    "instructions": {
      "orchestration": "Use the arxiv_search tool to find relevant research papers based on user queries.",
      "response": "Provide concise summaries of relevant papers. Include paper titles, authors, and key findings. Cite paper IDs when referencing specific works.",
      "sample_questions": [
        {"question": "What techniques exist for optimizing RAG retrieval performance?"},
        {"question": "What papers discuss GraphRAG or graph-augmented retrieval?"},
        {"question": "How can I improve RAG systems for non-English languages?"},
        {"question": "What are the latest approaches for reranking in RAG pipelines?"},
        {"question": "How can RAG systems run efficiently on consumer hardware?"}
      ]
    },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "arxiv_search",
          "description": "Search arXiv research papers about RAG, retrieval augmented generation, and AI systems"
        }
      }
    ],
    "tool_resources": {
      "arxiv_search": {
        "search_service": "POC.EASY_BUTTON_HOL.ARXIV_PAPERS_SEARCH_SERVICE",
        "max_results": 5,
        "columns": ["PAPER_ID", "TITLE", "FIRST_AUTHOR", "ABSTRACT", "PRIMARY_CATEGORY", "PDF_URL"]
      }
    }
  }
  $$;

-- Verify the agent
SHOW AGENTS IN SCHEMA POC.EASY_BUTTON_HOL;
DESCRIBE AGENT POC.EASY_BUTTON_HOL.ARXIV_RESEARCH_AGENT;

-- -----------------------------------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------------------------------
-- Objects created:
--   1. TABLE: POC.EASY_BUTTON_HOL.ARXIV_PAPERS_PARSED (3 papers with full text)
--   2. CORTEX SEARCH SERVICE: POC.EASY_BUTTON_HOL.ARXIV_PAPERS_SEARCH_SERVICE
--   3. AGENT: POC.EASY_BUTTON_HOL.ARXIV_RESEARCH_AGENT
--
-- To test the agent:
--   Go to Snowsight > AI & ML > Agents > ARXIV_RESEARCH_AGENT
--   Use the agent playground to ask questions like:
--     - "What techniques exist for optimizing RAG retrieval performance?"
--     - "What papers discuss GraphRAG?"
--     - "Tell me about RAG systems for Turkish language"
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CLEANUP: Drop created objects before re-running (preserves stage & metadata)
-- -----------------------------------------------------------------------------
DROP AGENT IF EXISTS POC.EASY_BUTTON_HOL.ARXIV_RESEARCH_AGENT;
DROP CORTEX SEARCH SERVICE IF EXISTS POC.EASY_BUTTON_HOL.ARXIV_PAPERS_SEARCH_SERVICE;
DROP TABLE IF EXISTS POC.EASY_BUTTON_HOL.ARXIV_PAPERS_PARSED;
