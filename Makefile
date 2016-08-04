VERSION = 2016.1
DESTDIR =
PREFIX = /usr
PACKAGE = rpm-hacks
PROGS = b64shar deb2spec rpm2spec rpmjail

build: $(PROGS)

$(PROGS):
	cp $@.sh $@

install: $(PROGS)
	install -Dm755 $(PROGS) $(DESTDIR)/usr/bin/$(PROGS)
	install -Dm644 macros.hacks-srpm $(DESTDIR)/usr/lib/rpm/macros.d/macros.hacks-srpm

uninstall:
        rm -f $(DESTDIR)$(PREFIX)/bin/$(PROGS)
        rm -f $(DESTDIR)/usr/lib/rpm/macros.d/macros.hacks-srpm  

clean:

rpm:
        rsync -aC --delete . $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION)
        tar czf $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION).tar.gz -C $(HOME)/rpmbuild/SOURCES $(PACKAGE)-$(VERSION)
        rpmbuild -ta $(HOME)/rpmbuild/SOURCES/$(PACKAGE)-$(VERSION).tar.gz
