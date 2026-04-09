VERSION := $(shell grep '^version' pyproject.toml | head -1 | sed 's/.*= *"\(.*\)"/\1/')
TARBALL := niri-display-manager-$(VERSION).tar.gz
DEB     := niri-display-manager_$(VERSION)_amd64.deb
RPM     := niri-display-manager-$(VERSION)-1.x86_64.rpm
STAGING := dist/staging

.PHONY: all build-tarball build-deb build-rpm build-all clean

all: build-all

build-all: build-tarball build-deb build-rpm

# ── Source tarball ────────────────────────────────────────────────────────────

build-tarball: dist/$(TARBALL)

dist/$(TARBALL):
	@mkdir -p dist
	git archive \
		--format=tar.gz \
		--prefix=niri_display_manager-$(VERSION)/ \
		HEAD \
		-o dist/$(TARBALL)
	@echo "Built dist/$(TARBALL)"

# ── Shared: build wheel and populate staging dir ─────────────────────────────

$(STAGING)/.done: dist/$(TARBALL)
	@echo "Building wheel..."
	python -m build --wheel --no-isolation
	@echo "Populating staging dir..."
	rm -rf $(STAGING)
	pip install --quiet --prefix=$(STAGING)/usr dist/*.whl
	install -dm755 $(STAGING)/usr/share/niri-display-manager
	cp -r qml $(STAGING)/usr/share/niri-display-manager/
	install -Dm644 packaging/io.github.rickycbanks.NiriDisplayManager.desktop \
		$(STAGING)/usr/share/applications/io.github.rickycbanks.NiriDisplayManager.desktop
	install -Dm644 assets/icons/niri-display-manager.svg \
		$(STAGING)/usr/share/icons/hicolor/scalable/apps/io.github.rickycbanks.NiriDisplayManager.svg
	install -Dm644 packaging/systemd/niri-display-manager-daemon.service \
		$(STAGING)/usr/lib/systemd/user/niri-display-manager-daemon.service
	install -Dm644 LICENSE \
		$(STAGING)/usr/share/licenses/niri-display-manager/LICENSE
	@touch $(STAGING)/.done

# ── .deb ─────────────────────────────────────────────────────────────────────

build-deb: dist/$(DEB)

dist/$(DEB): $(STAGING)/.done
	@command -v fpm >/dev/null 2>&1 || { echo "fpm not found. Install with: gem install fpm"; exit 1; }
	fpm \
		-s dir \
		-t deb \
		-C $(STAGING) \
		--name niri-display-manager \
		--version $(VERSION) \
		--iteration 1 \
		--architecture amd64 \
		--description "GUI display manager for the Niri Wayland window manager" \
		--url "https://github.com/rickycbanks/niri_display_manager" \
		--license MIT \
		--depends "python3 (>= 3.12)" \
		--depends "python3-pyside6" \
		--depends "python3-pyudev" \
		--package dist/$(DEB) \
		usr
	@echo "Built dist/$(DEB)"

# ── .rpm ─────────────────────────────────────────────────────────────────────

build-rpm: dist/$(RPM)

dist/$(RPM): $(STAGING)/.done
	@command -v fpm >/dev/null 2>&1 || { echo "fpm not found. Install with: gem install fpm"; exit 1; }
	fpm \
		-s dir \
		-t rpm \
		-C $(STAGING) \
		--name niri-display-manager \
		--version $(VERSION) \
		--iteration 1 \
		--architecture x86_64 \
		--description "GUI display manager for the Niri Wayland window manager" \
		--url "https://github.com/rickycbanks/niri_display_manager" \
		--license MIT \
		--depends "python3 >= 3.12" \
		--depends "python3-pyside6" \
		--depends "python3-pyudev" \
		--package dist/$(RPM) \
		usr
	@echo "Built dist/$(RPM)"

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	rm -rf dist/ $(STAGING)
	find . -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
