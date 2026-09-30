# AGENTS.md

Guidance for AI coding agents working in this repository. Setup and run instructions for humans live in `README.md`.

## What this is

An HR internal-policy chat assistant (RAG) in Ruby: a Sinatra app serves a chat page, and each question is sent to OpenAI `gpt-4o-mini` with context from the company policy PDF (`data/document_sample.pdf`).

It is a Ruby port of a Python/Streamlit project at `~/projects/my_simple_rag` and is kept **at the same step** as that project. Don't build ahead of it unless asked.

### Current step

- `Assistant.pdf_text` / `Assistant.split_pdf_text` load and chunk the PDF (1000 chars, 200 overlap).
- `Assistant.create_vector_database` embeds the chunks with OpenAI into a `Langchain::Vectorsearch::Hnswlib` store saved at `data/index.ann`. It embeds only when the file doesn't exist yet; otherwise it loads the saved index. Delete `data/index.ann` after changing the PDF.
- `Assistant#create_context` retrieves the `CONTEXT_CHUNKS` (4) nearest chunks. Hnswlib returns only ids, which are the chunk positions, so the assistant keeps the chunks array to look up their text. The PDF, chunks and store are built lazily on the first question.

## Stack

- Ruby 4.0.2 (`mise.toml`), Bundler
- langchainrb (`Langchain::LLM::OpenAI`, `Langchain::Loader`, `Langchain::Chunker::RecursiveText`, `Langchain::Vectorsearch::Hnswlib`) + ruby-openai + pdf-reader + hnswlib
- Sinatra 4 on Puma, started with `rackup` via `config.ru`
- RSpec + rack-test, RuboCop + rubocop-rspec
- dotenv for local secrets

## Commands

```bash
bundle install
bundle exec rackup          # http://localhost:9292 (-p <port> to change)
bundle exec rake            # specs + RuboCop — must pass before you finish
bundle exec rspec           # specs only
bundle exec rubocop -a      # lint and autocorrect
```

## Layout

```
config.ru                        # Rack entry point
data/document_sample.pdf         # knowledge base (git-ignored, see Gotchas)
data/index.ann                   # Hnswlib index, created on the first question (git-ignored)
lib/my_hnsw_rag.rb               # Bundler.require, dotenv, requires the app
lib/my_hnsw_rag/assistant.rb     # PDF helpers, prompt, context, LLM call
lib/my_hnsw_rag/web.rb           # Sinatra routes: GET /, POST /ask
lib/my_hnsw_rag/views/index.erb  # page markup only
lib/my_hnsw_rag/public/          # styles.css, app.js, favicon.svg/.ico, apple-touch-icon.png (served from /)
spec/                            # mirrors lib/; test_isolation_spec.rb checks the guards below
```

## HTTP API

`POST /ask` with JSON `{"question": "..."}`:

| Status | Body | When |
|--------|------|------|
| 200 | `{"answer": "..."}` | success |
| 400 | `{"error": "..."}` | body is not valid JSON |
| 422 | `{"error": "..."}` | blank question |
| 502 | `{"error": "..."}` | any error from the assistant/OpenAI (logged server-side) |

## Conventions

- **Language:** code, comments and docs in English; everything the user sees (UI text, prompt, error messages) in Brazilian Portuguese.
- **Indentation:** 2 spaces in every file, no tabs (`.editorconfig`).
- **Ruby style:** RuboCop is the source of truth (`# frozen_string_literal: true`, single quotes). Keep `bundle exec rake` at zero offenses.
- **Front end:** no inline `<style>` or `<script>` in `index.erb`. CSS goes in `public/styles.css`, JS in `public/app.js` (loaded with `defer`). Plain JS, no build step, no frameworks.
- **Theme:** Catppuccin, Latte for light mode and Mocha for dark mode, switched by `prefers-color-scheme`. Palette colors live only in the `--ctp-*` variables at the top of `styles.css`; rules use the semantic variables (`--bg`, `--fg`, `--accent`, `--error`, ...). Don't hardcode hex values elsewhere, and keep text contrast at 4.5:1 or better in both flavors.
- **Favicon:** `public/favicon.svg` is the source (Mocha base + mauve "R"). After editing it, regenerate the others: `rsvg-convert -w 180 favicon.svg -o apple-touch-icon.png` and a 16+32px `favicon.ico` with `magick`.
- **Spacing:** use the `--space-*` scale (4px steps) for all padding, margin and gap. No raw pixel values there.
- **Tests:** unit specs mock every dependency outside the class under test: the LLM, `Langchain::Loader`, PDF data and chunks, and the assistant in web specs. No real files, network or API clients. Use verifying doubles (`instance_double`); `verify_doubled_constant_names` is on, so doubling a class that doesn't exist fails. Specs never call OpenAI. Inject doubles with `Assistant.new(llm:, chunks:, vector_store:)` and set `MyHnswRag::Web.assistant = ...` in web specs (reset it to `nil` after). `spec_helper.rb` enforces this: WebMock blocks all real HTTP (a leaked call raises `WebMock::NetConnectNotAllowedError`), and a fake `OPENAI_API_KEY` is set before dotenv runs so the real key is never loaded. Don't loosen either; stub requests with WebMock if a spec needs HTTP.

## Gotchas

- `spec/spec_helper.rb` sets `APP_ENV=test` before loading the app. Without it, Sinatra's host authorization answers rack-test requests (`example.org`) with 403.
- `sinatra`, `puma` and `rackup` are `require: false` in the Gemfile. `Bundler.require` would otherwise load classic-mode Sinatra, which starts a server when the process exits. Require `sinatra/base` explicitly.
- The `logger` gem must stay in the Gemfile: langchainrb needs it, and it's no longer a default gem in Ruby 4.
- dotenv loads `.env.local` (path relative to `lib/`, not the working directory) unless `APP_ENV=production`. It's only in the development/test groups, so don't reference `Dotenv` outside that guard.
- `OPENAI_API_KEY` is read with `ENV.fetch` when the first question arrives; the page loads without it.
- Puma renames its process, so `pgrep rackup` won't find a running server. Find it by port (`ss -ltnp | grep 9292`) and stop it before starting another, or the new one fails with `EADDRINUSE` while the old code keeps answering.
- `data/` contents are git-ignored (only `data/.gitkeep` is tracked), so the PDF won't exist in a fresh clone. Never read it in specs; code that loads it at runtime should fail with a clear message when it's missing.
- Never commit `.env.local`; add new variables to `.env.example` with an empty value.
