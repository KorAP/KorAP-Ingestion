## KorAP Ingestion

Converts I5 XML files to KorAP XML, annotates them with TreeTagger, Marmot, Malt, Spacy, CoreNLP, OpenNLP, indexes them and starts a KorAP instance.

## Usage

By default, place your `.i5.xml` files in the `I5` directory in the root of the project:

```bash
make
```

Alternatively, you can specify a different source directory containing your `.i5.xml` files using the `SRC_DIR` variable:

```bash
make SRC_DIR=/path/to/your/files
```

Then open http://localhost:64543 in your browser.

## Prerequisites

* Java JRE 21 and 
* GNU Make
* Docker with compose

