SRC_DIR ?= I5

# Discover all *.i5.xml files in SRC_DIR
I5_FILES := $(wildcard $(SRC_DIR)/*.i5.xml)
BASENAMES := $(patsubst %.i5.xml,%,$(notdir $(I5_FILES)))

BUILD_DIR = build
TARGET_DIR ?= target
MAX_THREADS ?= 8 # $(shell nproc)
MAKE ?= make -j $(shell nproc)
KORAPXMLTOOL_HEAP ?= $(shell echo "$$(($(MAX_THREADS) * 2500))")
KORAPXMLTOOL ?= ./bin/korapxmltool

.DELETE_ON_ERROR:

.PHONY: all clean test index


.PRECIOUS: $(BUILD_DIR)/%.zip $(BUILD_DIR)/%.tree_tagger.zip $(BUILD_DIR)/%.marmot-malt.zip $(BUILD_DIR)/%.spacy.zip $(BUILD_DIR)/%.corenlp.zip $(BUILD_DIR)/%.opennlp.zip $(BUILD_DIR)/%.krill.tar %.i5.xml

all: index

index: $(TARGET_DIR)/index

$(BUILD_DIR)/%.zip: $(SRC_DIR)/%.i5.xml
	mkdir -p $(BUILD_DIR)
	tei2korapxml --progress -l warn -s -tk - < $< > $@
	printf "%s\t%s\n" "$(grep -c '<idsText ' $<)" "$(unzip -l $@ | grep data.xml | wc -l)"


$(BUILD_DIR)/%.tree_tagger.zip: $(BUILD_DIR)/%.zip bin/korapxmltool 
	$(KORAPXMLTOOL) -T treetagger -t zip --force -D $(BUILD_DIR) $<
#	 $(KORAPXMLTOOL) $< | pv | docker run --rm -i korap/conllu2treetagger -l german | conllu2korapxml > $@

$(BUILD_DIR)/%.spacy.zip: $(BUILD_DIR)/%.zip bin/korapxmltool 
	$(KORAPXMLTOOL) -T spacy -t zip --force -D $(BUILD_DIR) $<

bin/korapxmltool:
	mkdir -p bin
	curl -sL -o $@ https://github.com/korap/korapxmltool/releases/download/v3.1.0/korapxmltool
	chmod +x $@

models/de.marmot:
	mkdir -p models
	curl -sL -o $@ https://cistern.cis.lmu.de/marmot/models/CURRENT/spmrl/de.marmot

models/german.mco:
	mkdir -p models
	curl -sL -o $@  https://corpora.ids-mannheim.de/tools/$@

models/dereko_domains_s.classifier:
	mkdir -p models
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

models/german-fast.tagger:
	mkdir -p models
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

models/germanSR.ser.gz:
	mkdir -p models
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

models/de-pos-maxent.bin:
	mkdir -p models
	curl -sL -o $@ https://corpora.ids-mannheim.de/tools/$@

$(BUILD_DIR)/%.marmot-malt.zip:$(BUILD_DIR)/%.zip models/de.marmot models/german.mco  bin/korapxmltool 
	$(KORAPXMLTOOL) -T marmot:models/de.marmot -P malt:models/german.mco -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.corenlp.zip: $(BUILD_DIR)/%.zip models/german-fast.tagger models/germanSR.ser.gz bin/korapxmltool
	$(KORAPXMLTOOL) -T corenlp -P corenlp -t zip --force -D $(BUILD_DIR) $<

$(BUILD_DIR)/%.opennlp.zip: $(BUILD_DIR)/%.zip models/de-pos-maxent.bin bin/korapxmltool 
	$(KORAPXMLTOOL) -T opennlp -t zip --force -D $(BUILD_DIR) $<

# udpipe target removed as requested
# %.ud.zip: %.zip
#	$(KORAPXMLTOOL) $< | pv | ./scripts/udpipe2 | conllu2korapxml > $@

$(BUILD_DIR)/%.krill.tar: $(BUILD_DIR)/%.zip $(BUILD_DIR)/%.marmot-malt.zip $(BUILD_DIR)/%.tree_tagger.zip $(BUILD_DIR)/%.spacy.zip $(BUILD_DIR)/%.corenlp.zip $(BUILD_DIR)/%.opennlp.zip
	K2K_PUBLISHER_STRING=1 K2K_TRANSLATOR_TEXT=1 $(KORAPXMLTOOL) --non-word-tokens -f -t krill -D $(BUILD_DIR) $(basename $<)*.zip


$(TARGET_DIR)/index.tar.xz: $(TARGET_DIR)/index
	tar -I 'xz -T0' -C $(dir $<) -cf $@ $(notdir $<)

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)

$(TARGET_DIR)/index: $(foreach base,$(BASENAMES),$(BUILD_DIR)/$(base).krill.tar)
	rm -rf $@
	mkdir -p $(TARGET_DIR)
	java -jar lib/Krill-Indexer.jar --progress -c lib/krill.conf -i $(subst " ",;,$^) -o $@
