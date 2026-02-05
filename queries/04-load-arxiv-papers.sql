/*
=============================================================================
04 - Load arXiv Papers
=============================================================================
Execute the loader procedure and verify results
=============================================================================
*/

USE ROLE HOL_ROLE;
USE DATABASE POC;
USE SCHEMA EASY_BUTTON_HOL;

-- Load papers about RAG (Retrieval Augmented Generation) in NLP category
-- Change search_query and category as desired
-- Categories: cs.AI, cs.CL, cs.LG, cs.CV, cs.IR, stat.ML
CALL load_arxiv_papers('RAG', 'cs.CL', 3);

-- Refresh stage directory
ALTER STAGE ARXIV_PAPERS_STAGE REFRESH;

-- Check downloaded files
SELECT 
    RELATIVE_PATH as filename,
    ROUND(SIZE / 1024, 1) as size_kb,
    LAST_MODIFIED
FROM DIRECTORY(@ARXIV_PAPERS_STAGE) 
ORDER BY LAST_MODIFIED DESC;

-- Check metadata table
SELECT 
    paper_id,
    title,
    first_author,
    ARRAY_SIZE(authors) as author_count,
    primary_category,
    published_date,
    filename
FROM ARXIV_PAPERS_METADATA
ORDER BY published_date DESC;

-- Full metadata view
SELECT * FROM ARXIV_PAPERS_METADATA;
