---
description: Semantic code search via the semble MCP server
argument-hint: <natural-language query>
---

Run a semble code search and return concise, ranked results.

**Query:** $ARGUMENTS

Steps:

1. Call `mcp__semble__search` with:
   - `query`: the user's query above (verbatim)
   - `path`: the current working directory (`.`)
   - `top_k`: 8

2. For each returned chunk, summarise in **one line** as:

   `path:start_line-end_line — <one-sentence what this chunk does>`

3. After the list, name the **top 1–2 entry points** the user should open
   to investigate further. No prose intro, no closing summary.

If the query looks like a literal identifier, error message, or log line
(no natural-language structure), suggest `rg` instead and skip the search.
