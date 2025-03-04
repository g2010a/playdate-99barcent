SHELL := /bin/bash
OUT_FILENAME = builds/99barcent

all: build

release:
	$(eval VERSION := $(shell grep -o "version=.*" source/pdxinfo | cut -d= -f2))
	@read -p "Are you sure you want to release version $(VERSION)? (y/n): " confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "Release cancelled"; \
		exit 1; \
	fi
	make build
	git tag -a v$(VERSION) -m "Release $(VERSION)"
	git push origin v$(VERSION)

build:
	pdc source $(OUT_FILENAME)