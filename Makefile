# Makefile for kali-ormachy
# Automates building, testing, installation, and uninstallation.

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
XDG_CONFIG_HOME ?= $(HOME)/.config
CONFIGDIR ?= $(XDG_CONFIG_HOME)/ormachy-kali
DESTDIR ?=

CARGO ?= $(shell command -v cargo 2>/dev/null || echo $(HOME)/.cargo/bin/cargo)
CARGO_ENV = PATH="$$HOME/.cargo/bin:$$PATH"

.PHONY: all build test install uninstall clean

all: build

build:
	@$(CARGO_ENV) $(CARGO) build --release

test:
	@$(CARGO_ENV) $(CARGO) test
	@bash tests/rofi_launcher_test.sh
	@bash tests/installer_test.sh

install: build
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 target/release/kali-ormachy $(DESTDIR)$(BINDIR)/kali-ormachy
	install -m 755 scripts/kali-rofi-launcher.sh $(DESTDIR)$(BINDIR)/kali-ormachy-rofi
	install -d $(DESTDIR)$(CONFIGDIR)
	test -f $(DESTDIR)$(CONFIGDIR)/config.toml || install -m 644 config.default.toml $(DESTDIR)$(CONFIGDIR)/config.toml
	install -m 644 themes/kali-ormachy.rasi $(DESTDIR)$(CONFIGDIR)/kali-ormachy.rasi
	install -d $(DESTDIR)$(CONFIGDIR)/quickshell
	install -m 644 quickshell/*.qml $(DESTDIR)$(CONFIGDIR)/quickshell/
	@if [ -d "$(XDG_CONFIG_HOME)/omarchy" ]; then \
		install -d $(DESTDIR)$(XDG_CONFIG_HOME)/omarchy/plugins/kali-ormachy; \
		install -m 644 plugin/manifest.json $(DESTDIR)$(XDG_CONFIG_HOME)/omarchy/plugins/kali-ormachy/manifest.json; \
		install -m 644 plugin/BarWidget.qml $(DESTDIR)$(XDG_CONFIG_HOME)/omarchy/plugins/kali-ormachy/BarWidget.qml; \
	fi
	@echo "Installation completed successfully."
	@echo "Binaries installed to $(DESTDIR)$(BINDIR)"
	@echo "Configuration installed to $(DESTDIR)$(CONFIGDIR)"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/kali-ormachy
	rm -f $(DESTDIR)$(BINDIR)/kali-ormachy-rofi
	rm -f $(DESTDIR)$(CONFIGDIR)/kali-ormachy.rasi
	rm -rf $(DESTDIR)$(CONFIGDIR)/quickshell
	rm -rf $(DESTDIR)$(XDG_CONFIG_HOME)/omarchy/plugins/kali-ormachy
	@if [ -f "$(DESTDIR)$(CONFIGDIR)/config.toml" ]; then \
		echo "Note: $(DESTDIR)$(CONFIGDIR)/config.toml was preserved. Remove manually if desired."; \
	fi
	@rmdir $(DESTDIR)$(CONFIGDIR) 2>/dev/null || true
	@echo "kali-ormachy has been uninstalled."

clean:
	@$(CARGO_ENV) $(CARGO) clean
