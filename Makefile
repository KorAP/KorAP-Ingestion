SHELL := /bin/bash
SRC_DIR ?= I5
KORAP_PORT ?= 64543

# Discover all *.i5.xml files in SRC_DIR, excluding inlined tagged copies (*-TAG.i5.xml)
I5_FILES := $(filter-out %-TAG.i5.xml,$(wildcard $(SRC_DIR)/*.i5.xml))
BASENAMES := $(patsubst %.i5.xml,%,$(notdir $(I5_FILES)))

# Standard TEI P5 support
TEI_DIR ?= TEI
TEI_FILES := $(wildcard $(TEI_DIR)/*.xml)
# Same files as seen from inside the container (the dir is mounted at /input).
TEI_INPUTS := $(patsubst $(TEI_DIR)/%,/input/%,$(TEI_FILES))
TEI_ZIP_NAME ?= tei
TEI_FLAGS ?= --auto-textsigle 'TEI/XYZ.00001' # --xmlid-to-textsigle '([A-Z]+)\.(.*)\.([0-9]+)\.*([0-9])@$$1/$$2/$$3$$4'

# If set to a foundry name (e.g. gingko), tei2korapxml will use inline annotations and tokens from the source XML
USE_INLINE_ANNOTATIONS_AS ?=
TEI2KORAPXML_FLAGS ?= $(if $(USE_INLINE_ANNOTATIONS_AS),--no-tokenizer --inline-tokens $(USE_INLINE_ANNOTATIONS_AS),-s -tk)

ifneq ($(TEI_FILES),)
BASENAMES += $(TEI_ZIP_NAME)
endif

BUILD_DIR = build
TARGET_DIR ?= ./target
MAX_THREADS ?= 8 # $(shell nproc)
MAKE ?= make -j $(shell nproc)
# KORAPXMLTOOL_HEAP ?= $(shell echo "$$(($(MAX_THREADS) * 2500))")
KORAPXMLTOOL ?= ./bin/korapxmltool
KORAPXMLTOOL_MODELS_PATH ?= models
DOCKER_CPU_SHARES ?= # e.g. 512 for lower priority (default Docker value is 1024)

.DELETE_ON_ERROR:

.PHONY: all clean test index korap check-src pre-krill krill meta

.PRECIOUS: $(BUILD_DIR)/%.zip $(BUILD_DIR)/%.tree_tagger.zip $(BUILD_DIR)/%.marmot-malt.zip $(BUILD_DIR)/%.spacy.zip $(BUILD_DIR)/%.corenlp.zip $(BUILD_DIR)/%.cmc.zip $(BUILD_DIR)/%.opennlp.zip $(BUILD_DIR)/%.meta.xml $(BUILD_DIR)/%.krill.tar %.i5.xml

all: check-src korap

index: check-src $(TARGET_DIR)/index

check-src:
	@if [ ! -d "$(SRC_DIR)" ] && [ ! -d "$(TEI_DIR)" ]; then \
		echo "Error: Neither SRC_DIR '$(SRC_DIR)' nor TEI_DIR '$(TEI_DIR)' exists."; \
		echo "Please place your .i5.xml files in '$(SRC_DIR)' or your TEI .xml files in '$(TEI_DIR)'."; \
		exit 1; \
	fi
	@if [ -z "$$(find "$(SRC_DIR)" -maxdepth 1 -name '*.i5.xml' ! -name '*-TAG.i5.xml' -print -quit 2>/dev/null)" ] && \
	    [ -z "$$(find "$(TEI_DIR)" -maxdepth 1 -name '*.xml' -print -quit 2>/dev/null)" ]; then \
		echo "Error: No .i5.xml files found in '$(SRC_DIR)' and no .xml files found in '$(TEI_DIR)'."; \
		exit 1; \
	fi

$(BUILD_DIR)/%.zip: $(SRC_DIR)/%.i5.xml
	mkdir -p $(BUILD_DIR)
	docker run --rm -i $(if $(DOCKER_CPU_SHARES),--cpu-shares $(DOCKER_CPU_SHARES)) korap/tei2korapxml:latest -l warn $(TEI2KORAPXML_FLAGS) - < $< > $@ 2> >(tee $(@:.zip=.log) >&2)
#	docker run --rm $(if $(DOCKER_CPU_SHARES),--cpu-shares $(DOCKER_CPU_SHARES)) -v $(abspath $<):/input.i5.xml:ro korap/tei2korapxml:latest --progress -l warn $(TEI2KORAPXML_FLAGS) /input.i5.xml > $@ 2> >(tee $(@:.zip=.log) >&2)
	printf "%s\t%s\n" "$$(grep -c '<idsText ' $<)" "$$(unzip -l $@ | grep data.xml | wc -l)"

$(BUILD_DIR)/$(TEI_ZIP_NAME).zip: $(TEI_FILES)
	mkdir -p $(BUILD_DIR)
	docker run --rm $(if $(DOCKER_CPU_SHARES),--cpu-shares $(DOCKER_CPU_SHARES)) -v "$(abspath $(TEI_DIR)):/input:ro" korap/tei2korapxml:latest -l warn $(TEI2KORAPXML_FLAGS) $(TEI_FLAGS) $(TEI_INPUTS) > $@ 2> >(tee $(@:.zip=.log) >&2)
	printf "%s\t%s\n" "$$(cat $^ | grep -c '<teiHeader')" "$$(unzip -l $@ | grep data.xml | wc -l)"


$(BUILD_DIR)/%.tree_tagger.zip: $(BUILD_DIR)/%.zip | bin/korapxmltool
	$(KORAPXMLTOOL) -j 1 -T treetagger -t zip --force -D $(BUILD_DIR) $<
#	 $(KORAPXMLTOOL) $< | pv | docker run --rm -i korap/conllu2treetagger -l german | conllu2korapxml > $@

$(BUILD_DIR)/%.spacy.zip: $(BUILD_DIR)/%.zip | bin/korapxmltool
	$(KORAPXMLTOOL) -P spacy -t zip --force -D $(BUILD_DIR) $<

lib/Krill-Indexer.jar:
	mkdir -p lib
	curl -sL -o $@ https://github.com/korap/Krill/releases/latest/download/Krill-Indexer.jar

bin/korapxmltool:
	mkdir -p bin
	curl -sL -o $@ https://github.com/korap/korapxmltool/releases/latest/download/korapxmltool
	chmod +x $@

bin/conllu-gender:
	mkdir -p bin
	curl -sL -o $@ https://github.com/KorAP/conllu-gender/releases/latest/download/conllu-gender
	chmod +x $@

$(KORAPXMLTOOL_MODELS_PATH)/de.marmot:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@ https://cistern.cis.lmu.de/marmot/models/CURRENT/spmrl/de.marmot

$(KORAPXMLTOOL_MODELS_PATH)/german.mco:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@  https://corpora.ids-mannheim.de/tools/$@

$(KORAPXMLTOOL_MODELS_PATH)/dereko_domains_s.classifier:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/models/$@

$(KORAPXMLTOOL_MODELS_PATH)/german-fast.tagger:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

$(KORAPXMLTOOL_MODELS_PATH)/germanSR.ser.gz:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

$(KORAPXMLTOOL_MODELS_PATH)/de-pos-maxent.bin:
	mkdir -p $(KORAPXMLTOOL_MODELS_PATH)
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

$(BUILD_DIR)/%.marmot-malt.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/de.marmot $(KORAPXMLTOOL_MODELS_PATH)/german.mco | bin/korapxmltool
	$(KORAPXMLTOOL) -T marmot:models/de.marmot -P malt:models/german.mco -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.corenlp.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/german-fast.tagger $(KORAPXMLTOOL_MODELS_PATH)/germanSR.ser.gz | bin/korapxmltool
	$(KORAPXMLTOOL) -T corenlp -P corenlp -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.opennlp.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/de-pos-maxent.bin | bin/korapxmltool
	$(KORAPXMLTOOL) -T opennlp -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.cmc.zip: $(BUILD_DIR)/%.zip | bin/korapxmltool
	$(KORAPXMLTOOL) -j 1 -A "docker run --rm -i korap/conllu-cmc -s" -l error -F cmc -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.gender.zip: $(BUILD_DIR)/%.zip | bin/conllu-gender bin/korapxmltool
	$(KORAPXMLTOOL) -j 1 -A "bin/conllu-gender -s" -l WARNING -F gender -t zip --force -D $(BUILD_DIR) $<

# --- Stand-off metadata annotations -----------------------------------------
WIKI_TAXONOMY_IMAGE ?= korap/wiki-taxonomy

# Pass --gpus=all to GPU-capable docker runs when a CUDA GPU is usable, detected
# by nvidia-smi succeeding on the host. (The nvidia runtime is not listed in
# `docker info` when the Container Toolkit uses CDI, so we don't probe for it.)
# Probed once at parse time; override by setting GPU_FLAG (e.g. GPU_FLAG= to disable).
GPU_FLAG ?= $(shell if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then echo --gpus=all; fi)

# Wikipedia top-level topic-domain classification (annotation: wikidomain).
# Unlike the foundry annotations this yields a single stand-off metadata XML per
# corpus, not a per-text zip. The model is baked into the image, so nothing to mount.
$(BUILD_DIR)/%.wikidomain.meta.xml: $(BUILD_DIR)/%.zip | bin/korapxmltool
	set -o pipefail; $(KORAPXMLTOOL) -t now $< \
	  | docker run --rm -i $(GPU_FLAG) $(if $(DOCKER_CPU_SHARES),--cpu-shares $(DOCKER_CPU_SHARES)) \
	      $(WIKI_TAXONOMY_IMAGE) --topk 2 --threshold 0.4 > $@ 2> >(tee $(@:.xml=.log) >&2)

# udpipe target removed as requested
# %.ud.zip: %.zip
#	$(KORAPXMLTOOL) $< | pv | ./scripts/udpipe2 | conllu2korapxml > $@

# Active annotation layers to run and package into Krill. Most produce a per-text
# foundry zip; those also listed in META_ANNOTATIONS instead produce a single
# stand-off metadata XML per corpus (auto-detected by korapxmltool).
ANNOTATIONS ?= marmot-malt tree_tagger spacy corenlp opennlp wikidomain
META_ANNOTATIONS ?= wikidomain

# Build artifact produced by annotation $(2) for base $(1): a stand-off .meta.xml
# for meta-type annotations, otherwise a foundry .zip.
artifact = $(BUILD_DIR)/$(1).$(2).$(if $(filter $(2),$(META_ANNOTATIONS)),meta.xml,zip)
# Meta-type annotations that are actually active (must be passed to krill explicitly,
# since the recipe globs *.zip only).
ACTIVE_META := $(filter $(META_ANNOTATIONS),$(ANNOTATIONS))

KRILL_PREREQS := $(foreach base,$(BASENAMES),$(BUILD_DIR)/$(base).zip $(foreach ann,$(ANNOTATIONS),$(call artifact,$(base),$(ann))))

pre-krill: check-src $(KRILL_PREREQS)

# Build just the stand-off metadata layers without indexing.
meta: check-src $(foreach base,$(BASENAMES),$(foreach ann,$(ACTIVE_META),$(BUILD_DIR)/$(base).$(ann).meta.xml))

# The base zip, every annotation zip, and every stand-off meta XML are folded into
# one Krill tar. korapxmltool auto-detects the .meta.xml stand-off inputs.
$(BUILD_DIR)/%.krill.tar: $(BUILD_DIR)/%.zip $(foreach ann,$(ANNOTATIONS),$(call artifact,%,$(ann))) | bin/korapxmltool
	$(KORAPXMLTOOL) --non-word-tokens -f -t krill -D $(BUILD_DIR) $(basename $<)*.zip $(foreach ann,$(ACTIVE_META),$(BUILD_DIR)/$*.$(ann).meta.xml)

krill: $(foreach base,$(BASENAMES),$(BUILD_DIR)/$(base).krill.tar) 

$(TARGET_DIR)/index: $(foreach base,$(BASENAMES),$(BUILD_DIR)/$(base).krill.tar) 
	make lib/Krill-Indexer.jar
	touch lib/krill.cfg
	mkdir -p $(TARGET_DIR)
	java -jar lib/Krill-Indexer.jar -c lib/krill.cfg --progress -i $(subst " ",;,$^) -o $@

korap: check-src $(TARGET_DIR)/index
	curl -s https://raw.githubusercontent.com/KorAP/KorAP-Docker/master/compose.yaml | sed 's/64543:64543/$(KORAP_PORT):64543/g' | COMPOSE_PROFILES='export,open,lite' INDEX='$(TARGET_DIR)/index' docker compose -p korap -f - up

$(TARGET_DIR)/index.tar.xz: $(TARGET_DIR)/index
	tar -I 'xz -T0' -C $(dir $<) -cf $@ $(notdir $<)

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)
