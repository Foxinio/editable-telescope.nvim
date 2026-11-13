NVIM ?= nvim
DEPS := nvim-telescope/telescope.nvim nvim-lua/plenary.nvim
# Directory holding the dependencies; defaults to lazy.nvim's plugin directory.
export DEPS_DIR

.PHONY: test deps

test:
	@for t in tests/*.lua; do case "$$t" in */minimal_init.lua) continue;; esac; \
		$(NVIM) --headless -u tests/minimal_init.lua -l "$$t" || exit 1; done

deps:
	@mkdir -p .deps
	@for r in $(DEPS); do d=".deps/$${r#*/}"; [ -d "$$d" ] || git clone -q --depth 1 "https://github.com/$$r" "$$d"; done
