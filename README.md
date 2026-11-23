# Virtual Rabbit (Coelho virtual) — Godot 4 MVP

Low-poly **Godot 4.x** MVP (Linux): faceted island, spherical rabbit, CRT desk, cork board, **node graph** overlay, and **FSM** loop. Rabbit thoughts in **PT-BR** (character voice).

Visual reference: [@or1cinho](https://www.instagram.com/or1cinho/).

## Requirements

- **Godot 4.3+** (editor recommended)
- Ubuntu / Linux (headless tested with the official binary)
- Optional: [Ollama](https://ollama.com/) with `llama3.2:1b` (wander + ritual captions)
- Optional: [Wikimedia Enterprise](https://enterprise.wikimedia.com/docs/) token for CRT research (`ptwiki`)

## Quick start

```bash
git clone https://github.com/henricker/virtual-bunny.git
cd virtual-bunny
cp brain.env.example brain.env   # then edit (see below)
godot4 --path .                    # or open project.godot and press F5
```

Godot **does not** read your shell environment unless you launch from a terminal with `export …` or use **`brain.env`** in the project root (loaded by autoloads).

### `brain.env` (recommended)

```bash
cp brain.env.example brain.env
```

| Variable | Purpose |
|----------|---------|
| `BRAIN_API_URL` | Ollama base URL (default `http://127.0.0.1:11434`) |
| `BRAIN_MODEL` | Model name from `ollama list` (e.g. `llama3.2:1b`) |
| `WIKIMEDIA_ENTERPRISE_TOKEN` | Bearer JWT from Enterprise dashboard (~24h). **Never commit.** |
| `WIKIMEDIA_ENTERPRISE_PROJECT` | Wiki edition filter (default `ptwiki`) |

**Ollama**

```bash
ollama pull llama3.2:1b
ollama serve
```

**Output panel**

- `[BrainClient] usando Ollama model=…` — live LLM
- `[BrainClient] usando MOCK` — `brain/mock_responses.json`
- `[WikiLookup] sem token Enterprise` — research uses `brain/wiki_snippets.json`

Without Ollama, wander lines and rituals use **`brain/mock_responses.json`**.

## Wikipedia (Wikimedia Enterprise)

At the CRT, `BrainClient.research_thought()` calls `WikiLookup.search_async()`:

1. If **`WIKIMEDIA_ENTERPRISE_TOKEN`** is set → **On-demand API**  
   `POST https://api.enterprise.wikimedia.com/v2/articles/{Título}` with filter `ptwiki`
2. Else → local **`brain/wiki_snippets.json`**

The On-demand API needs an **exact article title** (not full-text search). The rabbit maps keywords from its question (e.g. grama → `Grama`, pedra → `Rocha`). Extend **`_candidate_titles()`** in `scripts/wiki_lookup.gd` for better hits.

UI **Pesquisas** lists query, excerpt, source (`wikimedia-enterprise` or `offline-wiki`), and article URL when available.

## Game loop (FSM)

Wander on the island → periodic **ritual**: derive thought → walk to PC → **research** → update **graph** → **sketch** on cork board.

Rough states: `idle` → `perceive` → `derive` → `walk_to_pc` → `research` → `update_graph` → `sketch_on_board` → `idle`

## Autoloads

| Name | Role |
|------|------|
| `BrainClient` | Ollama chat, quick thoughts, research + sketch captions |
| `WikiLookup` | Enterprise API + offline snippets |
| `ResearchLog` | History for **Pesquisas** panel |
| `SketchArchive` | Sketches for **Desenhos** panel |
| `PerceptionRegistry` | Island objects (`id`, label, 3D position) |

## UI

- **Pensamentos** — live thought line
- **Grafo** — node overlay from perception + research
- **Pesquisas** — research log (Enterprise or offline)
- **Desenhos** — procedural sketches from the ritual

## Project layout

```
project.godot
brain.env.example          # template (copy → brain.env, gitignored)
brain/
  mock_responses.json      # no Ollama
  wiki_snippets.json       # no Enterprise token
scenes/
  main.tscn
  thoughts_panel.tscn
  research_panel.tscn
  sketch_gallery_panel.tscn
scripts/
  rabbit_fsm.gd
  rabbit_avatar.gd
  island_builder.gd
  brain_client.gd
  wiki_lookup.gd
  research_log.gd
  sketch_generator.gd
  sketch_archive.gd
  board_sketches.gd
  perception_registry.gd
  ui/
    thoughts_ui.gd
    graph_ui.gd
    research_panel.gd
    sketch_gallery.gd
```

## Headless screenshot (optional)

```bash
/opt/godot/Godot_v4.3-stable_linux.x86_64 --path . --headless --script res://scripts/screenshot_runner.gd
```

## License

Experimental MVP — **Virtual Rabbit** project (Henrique Vieira).