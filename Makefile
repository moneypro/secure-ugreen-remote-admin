.PHONY: check audit-home audit-nas audit-aws

check:
	./tests/static.sh

audit-home:
	./bin/ugreen-remote audit-home

audit-nas:
	./bin/ugreen-remote audit-nas

audit-aws:
	./bin/ugreen-remote audit-aws

