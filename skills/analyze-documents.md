# Analyze Documents

Explore and understand the arXiv research papers in the Easy Button HOL.

## Triggers

- "Analyze my documents"
- "What data do I have?"
- "Help me understand these papers"
- "Explore the arXiv files"

## Context

You're working in the Easy Button HOL environment:
- **Database**: POC
- **Schema**: EASY_BUTTON_HOL  
- **Stage**: ARXIV_PAPERS_STAGE (PDF files downloaded from arXiv)
- **Metadata**: ARXIV_PAPERS_METADATA table

## Goal

Help the user understand what documents they have and what's inside them. Explore freely - check the stage, examine metadata, parse a few sample PDFs with `AI_PARSE_DOCUMENT`, and provide insights about the data.

## Exploration Guidelines

1. **Discover** - What files exist? What metadata is available? How do they relate?
2. **Sample** - Parse 1 PDF to see what the extracted content looks like
3. **Analyze** - What fields are useful for search? What should be filterable?
4. **Recommend** - Based on findings, what should the base table look like?

## Key Functions

- `DIRECTORY(@ARXIV_PAPERS_STAGE)` - List files in stage
- `TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', RELATIVE_PATH)` - Create FILE object for AI_PARSE_DOCUMENT
- `AI_PARSE_DOCUMENT(TO_FILE('@POC.EASY_BUTTON_HOL.ARXIV_PAPERS_STAGE', RELATIVE_PATH), {'mode': 'LAYOUT'})` - Parse PDFs
- `ARXIV_PAPERS_METADATA` - Table with paper metadata (title, authors, abstract, categories, dates)

**Important**: The stage uses server-side encryption (SNOWFLAKE_SSE) which is required for AI_PARSE_DOCUMENT. Use `TO_FILE()` with the fully-qualified stage name.

## Output

After exploring, provide:

1. **Summary** of what you found (document count, content structure, key fields)
2. **Sample content** showing extracted text quality
3. **Table design recommendation** - what columns should the parsed documents table have?
4. **A skill file** to create the base table

Generate a skill as a markdown code block the user can save to `skills/create-base-table.md`:

```markdown
# Create Base Table

[Skill that creates the parsed documents table based on your analysis]

## Output

After creating the table, generate a skill file for `skills/create-cortex-search.md` that builds the Cortex Search Service on this table.
```

The generated skill should include instructions to output the NEXT skill (create-cortex-search) after it completes.

## Notes

- Use HOL_ROLE, HOL_WH, POC.EASY_BUTTON_HOL
- Keep exploration conversational
- The generated skill should be specific to what you discovered
- Each skill in the chain generates the next one
