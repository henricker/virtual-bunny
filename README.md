# Virtual Rabbit (Coelho virtual) — Godot 4 MVP

Low-poly **Godot 4.x** MVP (Linux): faceted island, spherical rabbit, CRT desk, cork board, **node graph** overlay, and **FSM** loop. Rabbit thoughts in **PT-BR** (character voice).

Visual reference: [@or1cinho](https://www.instagram.com/or1cinho/).

## Requirements

- **Godot 4.3+** (editor recommended)
- Ubuntu / Linux (headless tested with the official binary)
- Optional: [Ollama](https://ollama.com/) with `llama3.2:1b`

## Run

```bash
git clone https://github.com/henricker/virtual-bunny.git
cd virtual-bunny
godot4 --path .   # or open project.godot in the editor and press F5
```

With Ollama (optional):

```bash
ollama pull llama3.2:1b
ollama serve
cp brain.env.example brain.env   # edit BRAIN_MODEL to match: ollama list
```

Or launch from a terminal:

```bash
export BRAIN_API_URL=http://127.0.0.1:11434
export BRAIN_MODEL=llama3.2:1b
godot4 --path .
```

Check the Godot **Output** panel: `[BrainClient] usando Ollama` = live LLM; `usando MOCK` = offline fallback.

Without Ollama, wander lines and rituals use **`brain/mock_responses.json`**.

## Wikipedia (Wikimedia Enterprise)

Research at the CRT uses the [Wikimedia Enterprise On-demand API](https://enterprise.wikimedia.com/docs/) (`ptwiki` by default). The game does **not** embed your token in the repo.

1. Copy `brain.env.example` → `brain.env` (already used for Ollama).
2. Set **`WIKIMEDIA_ENTERPRISE_TOKEN`** from the Enterprise dashboard (Bearer JWT, ~24h).
3. Optional: **`WIKIMEDIA_ENTERPRISE_PROJECT=ptwiki`**.

Without a token, `WikiLookup` falls back to **`brain/wiki_snippets.json`**. The API needs an **exact article title** — the rabbit maps keywords from its question (e.g. grama → `Grama`); you can extend the map in `scripts/wiki_lookup.gd`.

## FSM loop

`idle` → `perceive` → `derive` → (if `needs_web_search`) `walk_to_pc` → `research` → `update_graph` → `sketch_on_board` → `idle`

## Perception

Scene objects are registered in the `PerceptionRegistry` autoload (`id`, `label`, 3D position). See `scripts/island_builder.gd`.

## Brain (stub)

- Environment variable: **`BRAIN_API_URL`** (default `http://127.0.0.1:11434`)
- Client: `scripts/brain_client.gd` — Ollama `/api/chat` and `/api/tags`
- Fallback: `brain/mock_responses.json`

## Layout

```
project.godot
scenes/main.tscn
scripts/
  rabbit_fsm.gd
  island_builder.gd
  brain_client.gd
  perception_registry.gd
  ui/graph_ui.gd
  ui/thoughts_ui.gd
brain/mock_responses.json
```

## Headless screenshot (optional)

```bash
/opt/godot/Godot_v4.3-stable_linux.x86_64 --path . --headless --script res://scripts/screenshot_runner.gd
```

## License

Experimental MVP — **Virtual Rabbit** project (Henrique Vieira).