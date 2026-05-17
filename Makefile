PLASMOID_ID := me.dumke.kuma
PKG_DIR     := $(CURDIR)
BUILD_DIR   := build
PACK_NAME   := kuma-plasmoid.plasmoid

KPACKAGETOOL ?= $(shell command -v kpackagetool6 2>/dev/null || echo kpackagetool)
QMLLINT      ?= $(shell command -v qmllint6 2>/dev/null || command -v qmllint-qt6 2>/dev/null || echo qmllint)
PLASMOIDVIEW ?= $(shell command -v plasmoidviewer6 2>/dev/null || echo plasmoidviewer)
XGETTEXT     ?= xgettext
MSGFMT       ?= msgfmt
MSGMERGE     ?= msgmerge

QML_FILES := $(wildcard contents/ui/*.qml)
JS_FILES  := $(wildcard contents/code/*.js)
PO_FILES  := $(wildcard contents/locale/*/LC_MESSAGES/*.po)
MO_FILES  := $(PO_FILES:.po=.mo)
POT_FILE  := contents/locale/plasma_applet_me.dumke.kuma.pot

.PHONY: install upgrade reinstall remove pack clean lint pot translations \
        preview-panel preview-desktop preview-vertical

install: translations
	$(KPACKAGETOOL) --type Plasma/Applet --install $(PKG_DIR)

upgrade: translations
	$(KPACKAGETOOL) --type Plasma/Applet --upgrade $(PKG_DIR)

reinstall:
	$(KPACKAGETOOL) --type Plasma/Applet --remove $(PLASMOID_ID) || true
	$(MAKE) install

remove:
	$(KPACKAGETOOL) --type Plasma/Applet --remove $(PLASMOID_ID)

lint:
	$(QMLLINT) $(QML_FILES)

preview-panel: translations
	$(PLASMOIDVIEW) -a $(PLASMOID_ID) -f horizontal

preview-desktop: translations
	$(PLASMOIDVIEW) -a $(PLASMOID_ID) -f planar

preview-vertical: translations
	$(PLASMOIDVIEW) -a $(PLASMOID_ID) -f vertical

pot:
	mkdir -p contents/locale
	$(XGETTEXT) --from-code=UTF-8 -L JavaScript --keyword=i18n --keyword=i18nc:1c,2 \
	    --keyword=i18ncp:1c,2,3 --keyword=_ \
	    -o $(POT_FILE) $(QML_FILES) $(JS_FILES)

translations: $(MO_FILES)

%.mo: %.po
	$(MSGFMT) -o $@ $<

pack: translations
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp -r metadata.json contents $(BUILD_DIR)/
	cd $(BUILD_DIR) && zip -r ../$(PACK_NAME) .
	rm -rf $(BUILD_DIR)
	@echo "Built: $(PACK_NAME)"

clean:
	rm -rf $(BUILD_DIR) $(PACK_NAME)
	find contents/locale -name '*.mo' -delete 2>/dev/null || true
