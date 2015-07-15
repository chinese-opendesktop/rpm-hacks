PROGS = b64shar deb2spec rpm2spec rpmjail
.PHONY: all install

all: $(PROGS)

$(PROGS):
	cp $@.sh $@

install: $(PROGS)
	install -d $(DESTDIR)/usr/bin/
	install -m 755 $(PROGS) $(DESTDIR)/usr/bin/

