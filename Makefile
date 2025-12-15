SRC_DIR ?= I5

# Discover all *.i5.xml files in SRC_DIR
I5_FILES := $(wildcard $(SRC_DIR)/*.i5.xml)
BASENAMES := $(patsubst %.i5.xml,%,$(notdir $(I5_FILES)))

BUILD_DIR = build
TARGET_DIR ?= ./target
MAX_THREADS ?= 8 # $(shell nproc)
MAKE ?= make -j $(shell nproc)
# KORAPXMLTOOL_HEAP ?= $(shell echo "$$(($(MAX_THREADS) * 2500))")
KORAPXMLTOOL ?= ./bin/korapxmltool
KORAPXMLTOOL_MODELS_PATH ?= models

.DELETE_ON_ERROR:

.PHONY: all clean test index korap check-src

.PRECIOUS: $(BUILD_DIR)/%.zip $(BUILD_DIR)/%.tree_tagger.zip $(BUILD_DIR)/%.marmot-malt.zip $(BUILD_DIR)/%.spacy.zip $(BUILD_DIR)/%.corenlp.zip $(BUILD_DIR)/%.cmc.zip $(BUILD_DIR)/%.opennlp.zip $(BUILD_DIR)/%.krill.tar %.i5.xml

all: check-src korap

index: check-src $(TARGET_DIR)/index

check-src:
	@if [ ! -d "$(SRC_DIR)" ]; then \
		echo "Error: SRC_DIR '$(SRC_DIR)' does not exist."; \
		echo "Please create it and place your .i5.xml files there,"; \
		echo "or specify a different directory using SRC_DIR variable."; \
		echo "Example: make SRC_DIR=/path/to/files"; \
		exit 1; \
	fi
	@if [ -z "$$(find "$(SRC_DIR)" -maxdepth 1 -name '*.i5.xml' -print -quit)" ]; then \
		echo "Error: No .i5.xml files found in '$(SRC_DIR)'."; \
		echo "Please populate it or set SRC_DIR to a different location."; \
		exit 1; \
	fi

$(BUILD_DIR)/%.zip: $(SRC_DIR)/%.i5.xml
	mkdir -p $(BUILD_DIR)
	tei2korapxml --progress -l warn -s -tk $< > $@
	printf "%s\t%s\n" "$(grep -c '<idsText ' $<)" "$(unzip -l $@ | grep data.xml | wc -l)"


$(BUILD_DIR)/%.tree_tagger.zip: $(BUILD_DIR)/%.zip bin/korapxmltool 
	$(KORAPXMLTOOL) -j 1 -T treetagger -t zip --force -D $(BUILD_DIR) $<
#	 $(KORAPXMLTOOL) $< | pv | docker run --rm -i korap/conllu2treetagger -l german | conllu2korapxml > $@

$(BUILD_DIR)/%.spacy.zip: $(BUILD_DIR)/%.zip bin/korapxmltool 
	$(KORAPXMLTOOL) -P spacy -t zip --force -D $(BUILD_DIR) $<

lib/Krill-Indexer.jar:
	mkdir -p lib
	curl -sL -o $@ https://github.com/korap/Krill/releases/latest/download/Krill-Indexer.jar

bin/korapxmltool:
	mkdir -p bin
	curl -sL -o $@ https://github.com/korap/korapxmltool/releases/latest/download/korapxmltool
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

$(BUILD_DIR)/%.marmot-malt.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/de.marmot $(KORAPXMLTOOL_MODELS_PATH)/german.mco  bin/korapxmltool 
	$(KORAPXMLTOOL) -T marmot:models/de.marmot -P malt:models/german.mco -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.corenlp.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/german-fast.tagger $(KORAPXMLTOOL_MODELS_PATH)/germanSR.ser.gz bin/korapxmltool
	$(KORAPXMLTOOL) -T corenlp -P corenlp -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.opennlp.zip: $(BUILD_DIR)/%.zip $(KORAPXMLTOOL_MODELS_PATH)/de-pos-maxent.bin bin/korapxmltool 
	$(KORAPXMLTOOL) -T opennlp -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.cmc.zip: $(BUILD_DIR)/%.zip bin/korapxmltool 
	$(KORAPXMLTOOL) -j 1 -A "docker run --rm -i korap/conllu-cmc -s" -l error -F cmc -t zip --force -D $(BUILD_DIR) $<

# udpipe target removed as requested
# %.ud.zip: %.zip
#	$(KORAPXMLTOOL) $< | pv | ./scripts/udpipe2 | conllu2korapxml > $@

$(BUILD_DIR)/%.krill.tar: $(BUILD_DIR)/%.zip $(BUILD_DIR)/%.marmot-malt.zip $(BUILD_DIR)/%.tree_tagger.zip $(BUILD_DIR)/%.spacy.zip $(BUILD_DIR)/%.corenlp.zip $(BUILD_DIR)/%.opennlp.zip $(BUILD_DIR)/%.cmc.zip 
	K2K_PUBLISHER_STRING=1 K2K_TRANSLATOR_TEXT=1 $(KORAPXMLTOOL) --non-word-tokens -f -t krill -D $(BUILD_DIR) $(basename $<)*.zip

$(TARGET_DIR)/index: $(foreach base,$(BASENAMES),$(BUILD_DIR)/$(base).krill.tar) 
	make lib/Krill-Indexer.jar
	touch lib/krill.cfg
	mkdir -p $(TARGET_DIR)
	java -jar lib/Krill-Indexer.jar -c lib/krill.cfg --progress -i $(subst " ",;,$^) -o $@

korap: check-src $(TARGET_DIR)/index
	curl https://raw.githubusercontent.com/KorAP/KorAP-Docker/master/compose.yaml | INDEX='$(TARGET_DIR)/index' docker compose -p korap -f - --profile=lite --profile=example up

$(TARGET_DIR)/index.tar.xz: $(TARGET_DIR)/index
	tar -I 'xz -T0' -C $(dir $<) -cf $@ $(notdir $<)

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)
