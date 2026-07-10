.PHONY: check test smoke lint format

check: lint test

lint:
	stylua --check lua plugin tests

test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa

smoke:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration { minimal_init = 'tests/minimal_init.lua', sequential = true }" -c qa

format:
	stylua lua plugin tests
