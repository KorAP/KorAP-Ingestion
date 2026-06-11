## KorAP Ingestion

Converts TEI XML files to KorAP XML, annotates them with TreeTagger, Marmot, Malt, Spacy, CoreNLP, OpenNLP, indexes them and starts a KorAP instance.

## Usage (TEI I5)

By default, place your `.i5.xml` files in the `I5` directory in the root of the project:

```bash
make
```

Alternatively, you can specify a different source directory containing your `.i5.xml` files using the `SRC_DIR` variable:

```bash
make SRC_DIR=/path/to/your/files
```

Then open http://localhost:64543 in your browser.

If port `64543` is already in use on your host (e.g. by another process or IDE port-forwarding helper), you can specify a different host port using the `KORAP_PORT` variable:

```bash
make KORAP_PORT=64544
```

Then open the corresponding URL (e.g., http://localhost:64544) in your browser.

### Standard TEI P5 Support

Standard TEI P5 files (which typically contain one text per file) can be batch-converted together. By default, place your `.xml` files in the `TEI` directory in the root of the project:

```bash
make
```

All files in the `TEI` directory will be packaged into a single KorAP-XML zip archive.

You can specify a different source directory using the `TEI_DIR` variable:

```bash
make TEI_DIR=/path/to/your/tei/files
```

By default, texts are assigned automatic three-part KorAP/DeReKo sigles starting from:
```
--auto-textsigle 'TEI/XYZ.00001'
```
You can customize this or define a mapping from the `xml:id` of each text to a sigle. For example, if your XML files have IDs like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="SK.UL.1981.1" version="3.4.0">
  <teiHeader>
```

You can extract the three-part sigle (e.g., `SK/UL/19811`) by overriding the `TEI_FLAGS` variable with a matching regular expression:

```bash
make TEI_FLAGS='--xmlid-to-textsigle '\''([A-Z]+)\.(.*)\.([0-9]+)\.*([0-9])@$$1/$$2/$$3$$4'\'''
```

### Using Inline Annotations

If your source XML files already contain tokenization, sentence boundaries, and inline annotations that you want to use directly, you can set the `USE_INLINE_ANNOTATIONS_AS` variable to the name of the inline tokens foundry (e.g., `gingko`). This will pass the `--no-tokenizer --inline-tokens <foundry-name>` flags to `tei2korapxml` instead of the default `-s -tk` (sentence splitting and tokenization) flags:

```bash
make USE_INLINE_ANNOTATIONS_AS=gingko
```

### Configuring Active Annotators

You can specify which annotation layers to run and package by setting the `ANNOTATIONS` variable. By default, it runs:
`marmot-malt tree_tagger spacy corenlp opennlp wikidomain`

To enable gender annotation (using the `conllu-gender` tool), add `gender` to the list:

```bash
make ANNOTATIONS="marmot-malt tree_tagger spacy corenlp opennlp gender"
```

### Topic-domain Classification (stand-off metadata)

`wikidomain` is a special annotation: instead of a per-text foundry zip it produces a
single *stand-off metadata* XML per corpus (`build/<corpus>.wikidomain.meta.xml`) holding
Wikipedia top-level topic-domain classifications, generated with the `korap/wiki-taxonomy`
Docker image. korapxmltool auto-detects these `.meta.xml` files and folds them into the
Krill index as a `wikidomain` keywords field, queryable per text in KorAP.

It is enabled by default. Such metadata-producing layers are listed in `META_ANNOTATIONS`
(default: `wikidomain`); everything else in `ANNOTATIONS` is treated as a foundry zip. To
build just the classifications without indexing:

```bash
make meta
```

To disable it, drop it from `ANNOTATIONS` (e.g. `make ANNOTATIONS="marmot-malt spacy"`).

## Prerequisites

* Java JRE 21 and 
* GNU Make
* Docker with compose

