# One-command reproduction of the canonical results.
#
#   make run      build the image, run everything inside it, write
#                 logs/full_run_linux.txt, then check it against the
#                 acceptance criteria. This is the authoritative log.
#   make shell    interactive shell in the same container
#   make macos    host run, no valgrind, writes logs/full_run_macos.txt
#   make verify   re-check logs/full_run_linux.txt
#   make clean    remove build artifacts
#
# Sources are baked into the image (see the COPY in the Dockerfile) and results
# come back over stdout, so no bind mount is required. If your Docker Desktop
# file sharing does work, `make shell-mount` gives the live-edit workflow.

IMAGE    := apl-env
PLATFORM := linux/arm64

.PHONY: all run build shell shell-mount macos verify clean

all: run

build:
	docker build --platform $(PLATFORM) -t $(IMAGE) .

run: build
	@mkdir -p logs
	docker run --rm --platform $(PLATFORM) $(IMAGE) ./run_all.sh 2>&1 | tee logs/full_run_linux.txt
	@echo ""
	@$(MAKE) --no-print-directory verify

shell: build
	docker run --rm -it --platform $(PLATFORM) $(IMAGE)

# live-edit variant; needs working Docker Desktop file sharing
shell-mount: build
	docker run --rm -it --platform $(PLATFORM) -v "$(CURDIR)":/work -w /work $(IMAGE)

# secondary artifact: host toolchain (Apple clang, no valgrind)
macos:
	@mkdir -p logs
	./run_all.sh --no-valgrind 2>&1 | tee logs/full_run_macos.txt

verify:
	@./tools/verify_log.sh logs/full_run_linux.txt

clean:
	rm -f part2/java/*.class
