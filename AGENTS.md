# Project Architecture

## Project Setup

- This project uses Rojo for mapping
- This is a single-model-focused project. Meaning everything will be put into a single instance for drop-and-play

## Filesystem
- Paths must be relative. Using `game.<...>` is not allowed. Only `script.Parent.<...>` or `require("./<...>")`/`require("../<...>")`
- Folders should always be lowercased. Only exception is for folders with an `init.luau` file

## Engine Bootstrap and Constants

- `Engine` (`.../libraries/Engine.luau`) owns module loading and singleton lifecycle startup. Do not manually reproduce its work from a consumer.
- `Engine.loadModules(...sources)` requires every matching `ModuleScript` in each supplied source and, when the source itself is a `ModuleScript`, that source too. It intentionally ignores the return values; use it to execute registration/initialization modules.
- `Engine.loadSingletons(source)` loads the singleton modules in `source`, assigns any non-numeric `loadOrder` `math.huge`, and sorts all loaded singletons in ascending `loadOrder`.
- `Engine.launch()` runs each singleton's `init` through `noYield` (so it must not yield). In its second pass it spawns `start`.

## Networking
- Use `Remo` wally package for networking

# Luau Guidelines

## Code Structure

- Omit `--!strict`
- Strict block order: `--Services`, `--Imports`, `--Types`, `--Declarations`, `--Private Methods`, `--Public Methods`
- Do not add whitespace between the commented block and the following code. Keep whitespace between each new block
- Only add this block order for structured code (OOP, Controllers, Services, Libraries, etc.)
- Omit empty section headers — include only headers with content
- Types ALWAYS in `--Types`, never inline
- Top-level code (listeners, init calls, etc.) under `--Init` comment at bottom, after `--Private Methods` and `--Public Methods`
- Services and imports alphabetical by name
- Services and imports match service/module name in PascalCase

## Framework Singleton Pattern

- Singleton table: `const Name = {}`
- If `loadOrder` is not a number, omit it
- Block order adds `-- Lifecycle Methods` after `-- Public Methods`
- Lifecycle methods under `-- Lifecycle Methods`: `function Name.init()`, `function Name.start()`
- Return singleton directly: `return Name`

## Module Style

- If `.vscode/settings.json` does not exist, use `stringRequires` as false and `requireStyle` as `alwaysAbsolute` 
- Non-OOP modules: use `const function` for functions whose binding is never reassigned, return dictionary at bottom like `{funcName = funcName}`
- Separate internal/external functions with `-- Private Methods` and `-- Public Methods` comments

## Naming & Variables

- No single-letter variable names, use simple, readable, descriptive names
- Use `const` by default when the binding itself is never reassigned. This includes services, imports, module/singleton tables, required libraries, `RaycastParams` / modifier objects, immutable scoped calculations, and functions whose binding never changes (`const function name(...)`)
- Use `local` only when the binding is reassigned later, such as counters, state flags, retargeted values, variables built through multiple branches, or values intentionally changed in a loop/callback
- `const` does not mean the value is deeply immutable: a `const` table/object can still have fields changed or methods called. Choose `const` based on whether the variable name will point to a diferent value later
- Use `local function` only when a function binding genuienly needs reassignment; otherwise prefer `const function`
- Keep variables localized to the smallest practical scope; avoid declaring everything at the top when it can live near its use
- Do not create top-level constants or variables for values used only once or in one small block. Inline obvious one-off values, or declare them inside the function/block that needs them. Promote values to top-level only when they are reused across multiple places, define meaningful shared configuration, or clarify a non-obvious concept.

## Code Quality

- Prefer minimal helper functions. Only extract helpers when they reduce meaningful repetition, clarify a non-obvious block, or isolate reusable behavior
- Avoid local functions inside other local functions — prefer flat structure
- Avoid obvious/redundant comments. Comment only when genuinely complex, non-obvious, or unconventional
- Follow [Kampfkarren's Luau guidelines](https://github.com/Kampfkarren/kampfkarren-luau-guidelines)

## Workflow

- After every code edit, re-read affected script and do once-over to catch issues (duplicates, broken structure, misplaced blocks) before responding
- Scope discipline: don't edit scripts outside active task. If asked to scan/read a script, don't edit it. Revert any accidental edits before responding.
- Never commit the entire worktree as one commit merely for convenience. Inspect all outstanding changes first, then split unrelated features, fixes, assets, and documentation into separate commits, staging individual files or hunks when needed. A single commit is allowed only when every included change belongs to the same coherent unit of work.