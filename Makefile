PHONY = install uninstall test deb

ifeq ($(PREFIX), )
	PREFIX = /usr
endif

all:

clean:

test:

install:
	chown -R root.root include/*.sh
	chmod -R 644 include/*.sh
	mkdir -p $(DESTDIR)$(PREFIX)/share/toolbox/include
	cp -a include/ssh.sh $(DESTDIR)$(PREFIX)/share/toolbox/include/.

uninstall:
	rm $(DESTDIR)$(PREFIX)/share/toolbox/include/ssh.sh

deb:
	dpkg-buildpackage --no-sign

.PHONY: $(PHONY)
