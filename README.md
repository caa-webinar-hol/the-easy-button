# The Easy Button
### A Hands-On Lab for Cortex Knowledge Extensions, Snowflake Intelligence & Cortex Code

Transform unstructured documents into searchable knowledge with just a few clicks.

---

## What You'll Build

This lab demonstrates three powerful Snowflake capabilities working together:

### 1. Cortex Knowledge Extensions (CKE)
Turn PDFs and documents into searchable knowledge bases:
- **AI_PARSE_DOCUMENT** - Extract text and structure from PDFs
- **Cortex Search Service** - Semantic search over unstructured content
- **Deploy as Knowledge Extension** - Make your data available to Cortex agents

### 2. Snowflake Intelligence
Query your documents using natural language:
- Connect parsed documents to Snowflake Intelligence
- Ask questions in plain English
- Get AI-powered answers grounded in your data

### 3. Cortex Code (CoCo)
Accelerate development with AI-powered coding:
- **Data Exploration Skills** - Quickly understand your datasets
- **Search Service Creation** - Build Cortex Search with guided assistance
- **Custom Skills** - Create reusable workflows for your team

---

## Lab Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. INGEST      │     │  2. PROCESS     │     │  3. SEARCH      │
│                 │     │                 │     │                 │
│  Download PDFs  │────▶│  AI_PARSE_      │────▶│  Cortex Search  │
│  from arXiv     │     │  DOCUMENT       │     │  Service        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  6. SKILLS      │     │  5. AGENT       │     │  4. INTELLIGENCE│
│                 │     │                 │     │                 │
│  Cortex Code    │◀────│  Cortex Agent   │◀────│  Natural Lang   │
│  Skills         │     │  + CKE          │     │  Queries        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Prerequisites

### Snowflake Account Access

You need access to a Snowflake account with the ability to:
- Create roles, warehouses, databases, and schemas
- Create network rules and external access integrations
- Run Python stored procedures

#### Option 1: Use Your Organization's Account
If you have **ACCOUNTADMIN** or equivalent privileges, you can run these scripts directly.

#### Option 2: Snowflake Trial Account (Recommended for Learning)
If you don't have access to a Snowflake account or lack admin privileges:

1. Sign up for a [free 30-day Snowflake trial](https://signup.snowflake.com/)
2. Select **Enterprise** edition (required for Cortex features)
3. Choose **AWS** or **Azure** in a region that supports Cortex AI
4. You'll have full ACCOUNTADMIN access to experiment freely

> **Note**: Trial accounts include $400 in credits - more than enough for this lab.

### Required Privileges

| Object Type | Required Privilege | Granted By |
|-------------|-------------------|------------|
| Role | CREATE ROLE | ACCOUNTADMIN |
| Warehouse | CREATE WAREHOUSE | ACCOUNTADMIN |
| Database | CREATE DATABASE | ACCOUNTADMIN |
| Network Rule | CREATE NETWORK RULE | ACCOUNTADMIN |
| External Access Integration | CREATE INTEGRATION | ACCOUNTADMIN |
| Stored Procedure (with EAI) | USAGE ON INTEGRATION | ACCOUNTADMIN |

### Tools

- **Snowflake CLI** (`snow`) - [Installation Guide](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
- OR **Snowsight** (Snowflake web UI)

## Quick Start

### Using Snowflake CLI

```bash
# Set your connection (update with your connection name)
export SF_CONNECTION=your-connection-name

# Run scripts in order
snow sql -c $SF_CONNECTION -f queries/01-database-setup.sql
snow sql -c $SF_CONNECTION -f queries/02-arxiv-networking-setup.sql
snow sql -c $SF_CONNECTION -f queries/03-arxiv-data-loader-proc.sql --enable-templating NONE
snow sql -c $SF_CONNECTION -f queries/04-load-arxiv-papers.sql --enable-templating NONE
```

### Using Snowsight

1. Open [Snowsight](https://app.snowflake.com)
2. Navigate to **Worksheets**
3. Run each script in order (01 → 02 → 03 → 04)

## Deployment Scripts

### 01 - Database & Role Setup
**File**: `queries/01-database-setup.sql`

Creates the foundational infrastructure:
- `HOL_ROLE` - Role for running the demo
- `HOL_WH` - XSmall warehouse (auto-suspend 60s)
- `POC` database
- `EASY_BUTTON_HOL` schema

### 02 - arXiv Networking Setup
**File**: `queries/02-arxiv-networking-setup.sql`

Configures external network access:
- Network rule allowing `arxiv.org` and `export.arxiv.org`
- External Access Integration for API calls
- No API key required - arXiv is free and public

### 03 - Data Loader Procedure
**File**: `queries/03-arxiv-data-loader-proc.sql`

Creates data ingestion infrastructure:
- `ARXIV_PAPERS_STAGE` - Stage for PDF storage (directory enabled)
- `ARXIV_PAPERS_METADATA` - Table with paper metadata
- `load_arxiv_papers()` - Python stored procedure that:
  - Searches arXiv API by topic and category
  - Downloads PDFs to stage
  - Stores metadata (title, authors, abstract, categories, dates)

### 04 - Load Papers
**File**: `queries/04-load-arxiv-papers.sql`

Executes the loader and verifies results:
```sql
-- Load 5 papers about RAG in the NLP category
CALL load_arxiv_papers('RAG', 'cs.CL', 5);
```

#### arXiv Categories
| Category | Description |
|----------|-------------|
| cs.AI | Artificial Intelligence |
| cs.CL | Computation and Language (NLP) |
| cs.LG | Machine Learning |
| cs.CV | Computer Vision |
| cs.IR | Information Retrieval |
| stat.ML | Statistics - Machine Learning |

## Objects Created

| Object | Type | Owner |
|--------|------|-------|
| `HOL_ROLE` | Role | ACCOUNTADMIN |
| `HOL_WH` | Warehouse | HOL_ROLE |
| `POC` | Database | HOL_ROLE |
| `POC.EASY_BUTTON_HOL` | Schema | HOL_ROLE |
| `ARXIV_PAPERS_STAGE` | Stage | HOL_ROLE |
| `ARXIV_PAPERS_METADATA` | Table | HOL_ROLE |
| `load_arxiv_papers` | Procedure | HOL_ROLE |
| `arxiv_network_rule` | Network Rule | HOL_ROLE |
| `arxiv_integration` | External Access Integration | ACCOUNTADMIN |

## Troubleshooting

### "Role 'ACCOUNTADMIN' is not assigned"
You don't have admin privileges. Options:
- Ask your Snowflake admin to run scripts 01-02 for you
- Use a [Snowflake trial account](https://signup.snowflake.com/)

### "Network rule creation failed"
Network rules require ACCOUNTADMIN. Ask your admin or use a trial account.

### "External access integration error"
Your account may not have external access enabled. Contact Snowflake support or use a trial account.

### "Procedure execution timeout"
arXiv has rate limits. The procedure includes 0.5s delays between downloads. For large batches, run multiple smaller calls.

## Next Steps

After deploying these scripts:
1. Parse PDFs with `AI_PARSE_DOCUMENT`
2. Build a Cortex Search Service
3. Create Snowflake Intelligence data products
4. Develop Cortex Code skills for automation

## Resources

- [Snowflake Cortex Documentation](https://docs.snowflake.com/en/guides-overview-ai-features)
- [arXiv API Documentation](https://info.arxiv.org/help/api/index.html)
- [Cortex Search Service](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [External Access Integration](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

## License

This project is for educational purposes. arXiv papers are subject to their respective licenses.
