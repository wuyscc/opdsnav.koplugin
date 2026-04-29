# OPDSNav Plugin (`opdsnav.koplugin`)

A KOReader plugin that automatically seamlessly streams the next or previous item in an OPDS catalog. This is highly beneficial for continuous streaming of manga or comic series from servers like Kavita, Komga, or Kavita, minimizing the need to manually return to the OPDS browser to select the next chapter.

## Features

- **Continuous Page Streaming:** When using the "Page stream" feature in an OPDS catalog, reaching the end of a document and attempting to turn the page forward will automatically load the next document in the catalog.
- **Reverse Streaming:** Similarly, if you are on the very first page of a document and attempt to navigate backward, the plugin will load the previous document in the OPDS catalog and jump to its last page.
- **Cross-Pagination Support:** If the end of a current OPDS catalog page is reached, the plugin will automatically fetch the next page from the OPDS server and begin streaming the next item.
- **Smart Catalog Handling:** 
    - Automatically skips "Continue Reading from..." duplicate entries.
    - Supports detecting items marked as "[Read]" or with checkmarks (✔).
- **Asynchronous Transitions:** Non-blocking transitions with a "Loading" notification to keep the UI responsive.
- **Boundary Alerts:** Provides on-screen feedback when you reach the absolute beginning or end of a whole series.

## Configuration

The plugin settings can be found in the main KOReader menu under **OPDSNav**.

- **Enable OPDS Navigation:** Master toggle for the plugin logic.
- **Skip 'Continue From' item(s):** When enabled, the plugin resolves "Continue Reading" entries to the actual books to avoid redundant navigation.
- **Start next book from first page:** If enabled, moving to the next book always starts at page 1. If disabled, it respects the server's stored progress.

## Requirements

- **KOReader:** Requires a version supporting the `OPDSPSE` page streaming feature.
- **OPDS Source:** Designed for catalogs that provide "Page stream" capability (e.g., Kavita/Komga/Ubooquity serving images or PDFs). *This plugin does not affect standard downloaded local items.*

## Installation

1. Copy the entire `opdsnav.koplugin` folder to the `plugins/` directory of your KOReader installation.
2. Restart KOReader.
3. (Optional) Enable the plugin in **Tools** -> **Plugin management** if it's not enabled by default.

## Architecture

The project is structured for maintainability:
- `core/`: Main navigation logic and event hooks.
- `ui/`: Menu layouts and dialogs.
- `utils/`: Settings management and catalog helpers.
