.PHONY: build app run clean

build:
	swift build -c release

app: build
	@bash scripts/bundle.sh

run: app
	open OpenClaw.app

clean:
	swift package clean
	rm -rf OpenClaw.app
