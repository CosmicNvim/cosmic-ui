.PHONY: check test lint format

check: lint test

lint:
	stylua --check lua plugin tests

test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa

format:
	stylua lua plugin tests
