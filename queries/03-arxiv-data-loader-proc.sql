/*
=============================================================================
03 - arXiv Data Loader Procedure
=============================================================================
Creates:
  1. Stage for PDF storage
  2. Metadata table to track downloaded papers
  3. Stored procedure that:
     - Searches arXiv API for papers by topic/category
     - Parses XML response dynamically
     - Downloads papers as PDFs with rich filenames
     - Stores metadata for Cortex Search
=============================================================================
*/

USE ROLE HOL_ROLE;
USE DATABASE POC;
USE SCHEMA EASY_BUTTON_HOL;

-- Create stage for PDFs
CREATE OR REPLACE STAGE ARXIV_PAPERS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for arXiv research paper PDFs';

-- Create metadata table for downloaded papers
CREATE OR REPLACE TABLE ARXIV_PAPERS_METADATA (
    paper_id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(1000),
    authors ARRAY,
    first_author VARCHAR(200),
    abstract TEXT,
    categories ARRAY,
    primary_category VARCHAR(20),
    published_date DATE,
    updated_date DATE,
    pdf_url VARCHAR(500),
    stage_path VARCHAR(500),
    filename VARCHAR(500),
    arxiv_comment VARCHAR(500),
    downloaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create the loader procedure
CREATE OR REPLACE PROCEDURE load_arxiv_papers(
    search_query VARCHAR,
    category VARCHAR,
    max_papers INT
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'main'
EXTERNAL_ACCESS_INTEGRATIONS = (arxiv_integration)
AS
$$
import requests
import xml.etree.ElementTree as ET
import time
import json
import os

def safe_get_text(element, path, namespaces, default=""):
    found = element.find(path, namespaces)
    return found.text.strip() if found is not None and found.text else default

def safe_get_attr(element, path, attr, namespaces, default=""):
    found = element.find(path, namespaces)
    return found.get(attr, default) if found is not None else default

def extract_authors(entry, namespaces):
    authors = []
    for author in entry.findall("atom:author", namespaces):
        name = author.find("atom:name", namespaces)
        if name is not None and name.text:
            authors.append(name.text.strip())
    return authors

def extract_categories(entry, namespaces):
    categories = []
    for cat in entry.findall("atom:category", namespaces):
        term = cat.get("term")
        if term:
            categories.append(term)
    return categories

def get_pdf_link(entry, namespaces):
    for link in entry.findall("atom:link", namespaces):
        if link.get("title") == "pdf" or link.get("type") == "application/pdf":
            return link.get("href", "")
    return ""

def clean_for_filename(text, max_length=100):
    allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    cleaned = ""
    for c in text:
        if c in allowed:
            cleaned += c
        elif c == " ":
            cleaned += "_"
    return cleaned[:max_length]

def strip_version(paper_id):
    if not paper_id:
        return paper_id
    if paper_id[-2] == "v" and paper_id[-1].isdigit():
        return paper_id[:-2]
    if len(paper_id) > 2 and paper_id[-3] == "v" and paper_id[-2:].isdigit():
        return paper_id[:-3]
    return paper_id

def get_author_string(authors, max_authors=3):
    if not authors:
        return "Unknown"
    last_names = []
    for author in authors[:max_authors]:
        parts = author.split()
        last_names.append(parts[-1] if parts else "Unknown")
    if len(authors) > max_authors:
        return "_".join(last_names) + "_etal"
    return "_".join(last_names)

def main(session, search_query, category, max_papers):
    results = {
        "papers_found": 0,
        "papers_downloaded": 0,
        "papers_skipped": 0,
        "errors": [],
        "files": []
    }
    
    namespaces = {
        "atom": "http://www.w3.org/2005/Atom",
        "arxiv": "http://arxiv.org/schemas/atom"
    }
    
    query = "all:" + search_query
    if category:
        query = query + "+AND+cat:" + category
    
    api_url = "https://export.arxiv.org/api/query?search_query=" + query + "&start=0&max_results=" + str(max_papers) + "&sortBy=submittedDate&sortOrder=descending"
    
    try:
        response = requests.get(api_url, timeout=30)
        response.raise_for_status()
        
        root = ET.fromstring(response.content)
        entries = root.findall("atom:entry", namespaces)
        results["papers_found"] = len(entries)
        
        for entry in entries:
            try:
                id_full = safe_get_text(entry, "atom:id", namespaces)
                paper_id = id_full.split("/abs/")[-1] if "/abs/" in id_full else id_full
                paper_id_clean = strip_version(paper_id)
                
                title = safe_get_text(entry, "atom:title", namespaces).replace("\n", " ")
                abstract = safe_get_text(entry, "atom:summary", namespaces).replace("\n", " ")
                published = safe_get_text(entry, "atom:published", namespaces)[:10]
                updated = safe_get_text(entry, "atom:updated", namespaces)[:10]
                arxiv_comment = safe_get_text(entry, "arxiv:comment", namespaces)
                
                authors = extract_authors(entry, namespaces)
                categories = extract_categories(entry, namespaces)
                primary_category = safe_get_attr(entry, "arxiv:primary_category", "term", namespaces)
                if not primary_category and categories:
                    primary_category = categories[0]
                
                pdf_url = get_pdf_link(entry, namespaces)
                if not pdf_url:
                    pdf_url = "https://arxiv.org/pdf/" + paper_id + ".pdf"
                
                author_str = get_author_string(authors)
                raw_filename = paper_id_clean + "_" + published + "_" + author_str + "_" + primary_category
                filename = clean_for_filename(raw_filename, max_length=120) + ".pdf"
                stage_path = "@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE/" + filename
                
                pdf_response = requests.get(pdf_url, timeout=60)
                
                if pdf_response.status_code == 200 and len(pdf_response.content) > 1000:
                    # Write to temp file first, then PUT to stage
                    temp_path = "/tmp/" + filename
                    with open(temp_path, "wb") as f:
                        f.write(pdf_response.content)
                    
                    # Upload to stage
                    session.file.put(temp_path, "@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE", auto_compress=False, overwrite=True)
                    
                    # Clean up temp file
                    os.remove(temp_path)
                    
                    first_author = authors[0] if authors else "Unknown"
                    authors_json = json.dumps(authors)
                    categories_json = json.dumps(categories)
                    
                    merge_sql = """
                        MERGE INTO POC.EASY_BUTTON_HOL.ARXIV_PAPERS_METADATA t
                        USING (SELECT 
                            ? as paper_id,
                            ? as title,
                            PARSE_JSON(?) as authors,
                            ? as first_author,
                            ? as abstract,
                            PARSE_JSON(?) as categories,
                            ? as primary_category,
                            ?::DATE as published_date,
                            ?::DATE as updated_date,
                            ? as pdf_url,
                            ? as stage_path,
                            ? as filename,
                            ? as arxiv_comment
                        ) s
                        ON t.paper_id = s.paper_id
                        WHEN NOT MATCHED THEN INSERT 
                            (paper_id, title, authors, first_author, abstract, categories, 
                             primary_category, published_date, updated_date, pdf_url, 
                             stage_path, filename, arxiv_comment)
                        VALUES 
                            (s.paper_id, s.title, s.authors, s.first_author, s.abstract, 
                             s.categories, s.primary_category, s.published_date, s.updated_date,
                             s.pdf_url, s.stage_path, s.filename, s.arxiv_comment)
                    """
                    
                    session.sql(merge_sql, params=[
                        paper_id_clean, title, authors_json, first_author,
                        abstract, categories_json, primary_category,
                        published, updated, pdf_url, stage_path, filename, arxiv_comment
                    ]).collect()
                    
                    results["papers_downloaded"] += 1
                    results["files"].append({
                        "filename": filename,
                        "paper_id": paper_id_clean,
                        "title": title[:80],
                        "authors": authors[:3],
                        "category": primary_category,
                        "published": published
                    })
                    
                    time.sleep(0.5)
                else:
                    results["papers_skipped"] += 1
                    results["errors"].append("PDF download failed for " + paper_id + ": status=" + str(pdf_response.status_code))
                    
            except Exception as e:
                results["errors"].append("Error processing paper: " + str(e)[:100])
                
    except Exception as e:
        results["errors"].append("API error: " + str(e))
    
    return results
$$;

-- Verify
SHOW PROCEDURES LIKE 'load_arxiv%';
SHOW TABLES LIKE 'ARXIV_PAPERS%';
