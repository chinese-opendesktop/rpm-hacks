VERSION = 2023.3
DESTDIR =
PREFIX = /usr
PACKAGE = rpm-hacks
PROGS = b64shar deb2spec rpm2spec rpmjail ar2spec

build: $(PROGS)

$(PROGS):
	cp $@.sh $@

install: $(PROGS)
	install -d $(DESTDIR)/usr/bin
	install -m755 $(PROGS) $(DESTDIR)/usr/bin

uninstall:
	cd $(DESTDIR)$(PREFIX)/bin ; rm -f $(PROGS)

clean:

rpm: $(PACKAGE).spec
	rsync -aC --delete . $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION)
	tar czf $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION).tar.gz -C $(HOME)/rpmbuild/SOURCES $(PACKAGE)-$(VERSION)
	rpmbuild -ta $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION).tar.gz
