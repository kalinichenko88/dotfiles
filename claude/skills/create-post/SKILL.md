---
name: create-post
description: Creates blog posts for kalinichenko.dev from rough Russian technical drafts or notes. Translates into clear, natural English while preserving technical accuracy, code examples, and the author's personal voice, and writes the post into content/posts/. Use when turning a Russian draft or a list of notes into a new blog post.
---

# Create Blog Post

Creates English blog posts from rough Russian technical drafts. The output should read like something a developer wrote on a Sunday afternoon, not like marketing copy or an AI-generated article.

## Author Context

The author is Ivan Kalinichenko, a Senior Frontend Engineer with 10+ years of experience. Expertise: React, TypeScript, Next.js, Vue.js, Node.js, NestJS, GraphQL, and infrastructure (CI/CD, Docker, testing, performance), plus mentoring, code review, hiring, and onboarding. Day job: the frontend of a self-hosted product, with AI tools as part of the daily workflow. The blog lives at kalinichenko.dev and mostly covers developer tooling: Claude Code, Neovim, Obsidian, git.

The repo is the source of truth for this: `ROLE` and `SITE_DESCRIPTION` in `src/consts.ts`, the expertise list in `src/config/resume.ts`. If they disagree with the paragraph above, follow the repo.

The author's writing style is direct and slightly ironic. He doesn't hedge or soften opinions: if something is bad, he says it's bad. No "this might not be ideal" when "this is bad" works.

Keep this context in mind when translating: the author writes from a position of deep technical experience.

## Core Principles

### 1. Simple Language
- Target B1-B2 English level for non-technical prose
- Use "use" not "utilize", "start" not "initialize" (when not a technical term), "show" not "demonstrate", "try" not "attempt"
- Prefer short, common words over fancy ones
- Prefer simple sentence structures
- Technical terms can be advanced; surrounding prose should be plain
- Avoid uncommon idioms that non-native speakers won't know

### 2. Natural Language
- Write how developers actually talk to each other
- Avoid corporate-speak, buzzwords, and marketing fluff
- Use contractions (it's, don't, we'll)
- Break up dense paragraphs into digestible chunks

### 3. Preserve Technical Integrity
- Keep all technical terms precise and accurate
- Don't oversimplify or dumb down concepts
- Maintain code examples exactly as provided
- Preserve variable names, function names, and technical references
- Use industry-standard terminology

### 4. Human Voice
- Keep the author's personal insights and experiences
- Maintain first-person perspective when present
- Preserve humor, frustration, or excitement from the original
- Keep opinions and hot takes

### 5. Imperfect is Human
- Not every section needs a smooth transition
- It's fine to jump between ideas without a bridge sentence
- Don't wrap up every section with a neat conclusion
- A one-sentence paragraph is fine
- Skip "setup" sentences like "Let's look at..." or "Here's how it works:". Just show the code or explain the thing directly
- The post doesn't need to feel "complete" or "polished". Slightly rough is better than too smooth

### 6. Avoid AI Writing Patterns
Never use these:
- "In today's fast-paced world of..."
- "It's worth noting that..."
- "Let's dive deep into..."
- "At the end of the day..."
- "In this article we will..."
- Excessive use of "robust," "leverage," "utilize," "powerful"
- Lists that start every item with the same verb
- Filler phrases: "In order to" (→ "To"), "Due to the fact that" (→ "Because"), "It is important to note that" (→ just say it), "has the ability to" (→ "can")

Also avoid these subtler AI patterns:
- Dramatic short sentence endings ("And it works every time.")
- Rule of three constructions ("No X. No Y. Just Z.")
- "The key insight/takeaway is..."
- "turned out to be straightforward"
- "surprisingly" + adjective ("surprisingly annoying", "surprisingly tricky")
- Rhetorical questions followed by immediate answers
- Starting conclusions with "The" + abstract noun ("The fix:", "The solution:")
- Wrapping up with a grand statement about a broader principle
- Copula avoidance: don't write "serves as", "stands as", "functions as" when "is" works
- Superficial -ing phrases tacked onto sentences: "highlighting the importance of...", "showcasing how...", "emphasizing the need for..."
- Significance inflation: "crucial", "pivotal", "testament", "enduring legacy", "marking a shift". Just state the fact
- Synonym cycling: don't repeat the same idea with different words to avoid repetition ("the tool / the assistant / the system" for the same thing)
- Negative parallelisms: "It's not just X, it's Y", "Not only...but also..."
- Em dashes (`—`) and en dashes (`–`): none at all. The site bans them in visible copy (`DESIGN.md` in the repo) and the recent posts carry zero. Use a comma, a period, a colon or parentheses instead
- Inline-header lists: don't format lists as "**Bold label:** description". Write normal sentences or plain list items

### 7. Titles and Headings
- Keep titles descriptive, not clever or clickbaity
- Don't use "That Actually...", "You Need to Know", "The Right Way" patterns
- Section headings should describe content, not tease it
- Good title: "Generating commit messages with Copilot in Neovim"
- Bad title: "AI-Powered Commit Messages That Actually Follow Your Rules"
- Good heading: "Commit rules file"
- Bad heading: "The Fix: Be Explicit in the Prompt"

## Translation Workflow

### Step 1: Understand the Context
Before translating:
- Identify the article type (tutorial, deep dive, problem-solving, tool review)
- Note the author's tone (excited, frustrated, curious, opinionated)
- Check for code examples and technical terms
- Understand the target audience level

### Step 2: Translate for Meaning, Not Words
- Focus on conveying ideas, not literal word-for-word translation
- Restructure sentences for English flow when needed
- Keep paragraphs focused on one main idea

### Step 3: Handle Technical Content
- **Code blocks**: Copy as-is, no translation
- **Variable/function names**: Keep original, even if in Russian transliteration
- **Technical terms**: Use standard English equivalents (компонент -> component, хук -> hook)
- **Framework names**: Keep original (React, Vue, TypeScript)
- **Comments in code**: Translate to English

### Step 4: Maintain Structure
Preserve the original:
- Section breaks and headings
- Numbered/bulleted lists
- Code example placement
- Emphasis (bold, italic)
- Links and references

### Step 5: Simplify
- Break run-on sentences
- Use active voice
- Cut unnecessary words
- Replace complex words with simple ones
- Remove any sentence that exists only for "flow" and doesn't add information

## Example Transformations

```
Bad:  "Now we should implement the function which will handle..."
Good: "Next, write a function that handles..."

Bad:  "It is important to note that..."
Good: "Watch out:"

Bad:  "The solution turned out to be straightforward"
Good: "The fix is simple"
```

## Quality Checks

Before finishing, verify:
- [ ] Would a native speaker write this way?
- [ ] Is the vocabulary simple (B1-B2 for non-technical prose)?
- [ ] Are technical terms accurate?
- [ ] Does it sound like a human developer wrote it?
- [ ] Are code examples intact?
- [ ] Is the author's voice preserved: direct, no hedging, opinions intact?
- [ ] No AI-writing patterns (including subtle ones)?
- [ ] Title is descriptive, not clickbaity?
- [ ] No rule-of-three or dramatic one-liner constructions?
- [ ] No unnecessary "flow" or "bridge" sentences?
- [ ] Post length is reasonable: expanded from notes but not padded?
- [ ] No em dashes or en dashes anywhere in the post?
- [ ] 2 to 3 tags, reused from existing posts, most specific first?
- [ ] Frontmatter is complete (title, description, pubDate, tags)?

## Common Patterns to Fix

### Russian to English Tech Writing

**Formal Russian structures:**
```
Russian: "В данной статье мы рассмотрим..."
Bad:  "In this article we will consider..."
Good: (drop the sentence and start with the actual content)
```

**Passive constructions:**
```
Russian passive tendency
Bad:  "The component was created by..."
Good: "I created the component..."
```

**Verbose expressions:**
```
Bad:  "It is necessary to perform the following actions..."
Good: (drop the sentence and go straight to the steps)
```

**Technical precision:**
```
Bad:  "We utilized the useEffect dependency array..."
Good: "We used the useEffect dependency array..."
```

## Edge Cases

### Mixed Language Code
When code has Russian comments:
```javascript
// Плохо: оригинальный комментарий
// Bad: original comment
```

### Cultural References
- Keep cultural references unless they make the point impossible to understand without context
- If a reference might confuse an international audience, ask the author before removing or adapting it

### Abbreviations
- Expand Russian abbreviations that don't translate
- Use standard English tech abbreviations
- Spell out on first use if uncommon

## Post Length

The draft is usually bullet points or rough notes. Expand them into a real post, but keep it short. This is a personal dev blog, not a corporate publication. Don't pad with filler to make it longer.

## Handling Ambiguity

If something in the draft is unclear (an ambiguous phrase, missing context, an unclear technical detail), ask the author before guessing. Same for links to Russian-language resources: ask if there's an English alternative.

## Output Format

Write the post to `content/posts/<slug>.md` in the site repo. The file name is the URL slug (`/blog/<slug>`), so make it short, lowercase, hyphenated English. Use `.mdx` only when the post imports a component.

Frontmatter follows the `posts` schema in `src/content.config.ts`:

```md
---
title: 'Descriptive title here'
description: 'One-sentence summary'
pubDate: YYYY-MM-DD
tags: [tool-tag, topic-tag]
---

Post content here.
```

- `pubDate` is today's date unless the author gives another.
- Tags follow the Tags section of the repo's `CLAUDE.md`: 2 to 3 tags, reuse the ones existing posts already use (`grep -h '^tags' content/posts/*`), most specific first, because the first tag is the chip on `/blog`.
- Images go in `src/assets/images/` and are referenced with a relative path (`../../src/assets/images/foo.png`) so Astro optimizes them.
- A custom component needs its import at the top of an `.mdx` post, e.g. `import VideoPlayer from '../../src/components/VideoPlayer.astro';`.

Do NOT add to the post:
- Meta commentary about the translation
- "Translated from Russian" notes
- Explanations of choices made
- Your own opinions or additions

After writing the file, run `npm run build` in the repo: it validates the frontmatter against the schema. Then tell the author the file path and any question from *Handling Ambiguity* that is still open.
