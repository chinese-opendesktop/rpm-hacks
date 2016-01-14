PROGS = b64shar deb2spec rpm2spec rpmjail
.PHONY: build install

build: $(PROGS)

$(PROGS):
	cp $@.sh $@

install: $(PROGS)
	install -d $(DESTDIR)/usr/bin/
	install -m 755 $(PROGS) $(DESTDIR)/usr/bin/
	install -d $(DESTDIR)/usr/lib/rpm/macros.d/
	install -m 644 macros.hacks-srpm $(DESTDIR)/usr/lib/rpm/macros.d/
