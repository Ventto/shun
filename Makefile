PKGNAME = shun
BIN 	= $(PKGNAME).sh

SHAREDIR = /usr/share/$(PKGNAME)
BINDIR   = /usr/bin

.PHONY: all
all:
	@echo

.PHONY: install
install: $(SHAREDIR)
	cp sc-codes $(SHAREDIR)/sc-codes
	cp $(BIN) $(BINDIR)/$(PKGNAME)

.PHONY: uninstall
uninstall:
	$(RM) -r $(SHAREDIR)
	$(RM) $(BINDIR)/$(PKGNAME)

$(SHAREDIR):
	mkdir -p $(SHAREDIR)

