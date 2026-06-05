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

### Configuring Active Annotators

You can specify which annotation layers to run and package by setting the `ANNOTATIONS` variable. By default, it runs:
`marmot-malt tree_tagger spacy corenlp opennlp`

To enable gender annotation (using the `conllu-gender` tool), add `gender` to the list:

```bash
make ANNOTATIONS="marmot-malt tree_tagger spacy corenlp opennlp gender"
```

## Prerequisites

* Java JRE 21 and 
* GNU Make
* Docker with compose

