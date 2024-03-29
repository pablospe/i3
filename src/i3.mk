ALL_TARGETS += i3
INSTALL_TARGETS += install-i3
CLEAN_TARGETS += clean-i3

i3_SOURCES           := $(filter-out $(i3_SOURCES_GENERATED),$(wildcard src/*.c))
i3_HEADERS_CMDPARSER := $(wildcard include/GENERATED_*.h)
i3_HEADERS           := $(filter-out $(i3_HEADERS_CMDPARSER),$(wildcard include/*.h))
i3_CFLAGS             = $(XCB_CFLAGS) $(XCB_KBD_CFLAGS) $(XCB_WM_CFLAGS) $(X11_CFLAGS) $(XCURSOR_CFLAGS) $(PANGO_CFLAGS) $(YAJL_CFLAGS) $(LIBEV_CFLAGS) $(PCRE_CFLAGS) $(LIBSN_CFLAGS)
i3_LIBS               = $(XCB_LIBS) $(XCB_KBD_LIBS) $(XCB_WM_LIBS) $(X11_LIBS) $(XCURSOR_LIBS) $(PANGO_LIBS) $(YAJL_LIBS) $(LIBEV_LIBS) $(PCRE_LIBS) $(LIBSN_LIBS) -lm -lpthread

# When using clang, we use pre-compiled headers to speed up the build. With
# gcc, this actually makes the build slower.
ifeq ($(CC),clang)
i3_HEADERS_DEP       := $(i3_HEADERS) include/all.h.pch
PCH_FLAGS            := -include include/all.h
else
i3_HEADERS_DEP       := $(i3_HEADERS)
PCH_FLAGS            :=
endif

i3_OBJECTS := $(i3_SOURCES_GENERATED:.c=.o) $(i3_SOURCES:.c=.o)

# The basename/pwd calls are for canonicalizing the path: Instead
# of src/main.c, we will see something like ../i3-4.2/src/main.c in
# debugger backtraces, making it clearer which code belongs to i3 and
# which code doesn’t.
# We only do this for src/ since all the other subdirectories contain i3 in
# their name already.
canonical_path := ../$(shell basename $(shell pwd -P))

include/all.h.pch: $(i3_HEADERS)
	echo "[i3] PCH all.h"
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) -x c-header include/all.h -o include/all.h.pch

src/%.o: src/%.c $(i3_HEADERS_DEP)
	echo "[i3] CC $<"
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) $(PCH_FLAGS) -c -o $@ ${canonical_path}/$<

# This target compiles the command parser twice:
# Once with -DTEST_PARSER, creating a stand-alone executable used for tests,
# and once as an object file for i3.
src/commands_parser.o: src/commands_parser.c $(i3_HEADERS_DEP) i3-command-parser.stamp
	echo "[i3] CC $<"
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) $(I3_LDFLAGS) $(LDFLAGS) -DTEST_PARSER -g -o test.commands_parser $< $(LIBS) $(i3_LIBS)
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) -c -o $@ ${canonical_path}/$<

# This target compiles the command parser twice:
# Once with -DTEST_PARSER, creating a stand-alone executable used for tests,
# and once as an object file for i3.
src/config_parser.o: src/config_parser.c $(i3_HEADERS_DEP) i3-config-parser.stamp
	echo "[i3] CC $<"
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) $(I3_LDFLAGS) $(LDFLAGS) -DTEST_PARSER -g -o test.config_parser $< $(LIBS) $(i3_LIBS)
	$(CC) $(I3_CPPFLAGS) $(XCB_CPPFLAGS) $(CPPFLAGS) $(i3_CFLAGS) $(I3_CFLAGS) $(CFLAGS) -c -o $@ ${canonical_path}/$<

i3-command-parser.stamp: generate-command-parser.pl parser-specs/commands.spec
	echo "[i3] Generating command parser"
	(cd $(TOPDIR)/include; ../generate-command-parser.pl --input=../parser-specs/commands.spec --prefix=command)
	touch $@

i3-config-parser.stamp: generate-command-parser.pl parser-specs/config.spec
	echo "[i3] Generating config parser"
	(cd $(TOPDIR)/include; ../generate-command-parser.pl --input=../parser-specs/config.spec --prefix=config)
	touch $@

i3: libi3.a $(i3_OBJECTS)
	echo "[i3] Link i3"
	$(CC) $(I3_LDFLAGS) $(LDFLAGS) -o $@ $(filter-out libi3.a,$^) $(LIBS) $(i3_LIBS)

install-i3: i3
	echo "[i3] Install"
	$(INSTALL) -d -m 0755 $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -d -m 0755 $(DESTDIR)$(SYSCONFDIR)/i3
	$(INSTALL) -d -m 0755 $(DESTDIR)$(PREFIX)/include/i3
	$(INSTALL) -d -m 0755 $(DESTDIR)$(PREFIX)/share/xsessions
	$(INSTALL) -d -m 0755 $(DESTDIR)$(PREFIX)/share/applications
	$(INSTALL) -m 0755 i3 $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -m 0755 i3-migrate-config-to-v4 $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -m 0755 i3-sensible-editor $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -m 0755 i3-sensible-pager $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -m 0755 i3-sensible-terminal $(DESTDIR)$(PREFIX)/bin/
	$(INSTALL) -m 0755 i3-dmenu-desktop $(DESTDIR)$(PREFIX)/bin/
	test -e $(DESTDIR)$(SYSCONFDIR)/i3/config || $(INSTALL) -m 0644 i3.config $(DESTDIR)$(SYSCONFDIR)/i3/config
	test -e $(DESTDIR)$(SYSCONFDIR)/i3/config.keycodes || $(INSTALL) -m 0644 i3.config.keycodes $(DESTDIR)$(SYSCONFDIR)/i3/config.keycodes
	$(INSTALL) -m 0644 i3.xsession.desktop $(DESTDIR)$(PREFIX)/share/xsessions/i3.desktop
	$(INSTALL) -m 0644 i3.applications.desktop $(DESTDIR)$(PREFIX)/share/applications/i3.desktop
	$(INSTALL) -m 0644 include/i3/ipc.h $(DESTDIR)$(PREFIX)/include/i3/

clean-i3:
	echo "[i3] Clean"
	rm -f $(i3_OBJECTS) $(i3_SOURCES_GENERATED) $(i3_HEADERS_CMDPARSER) include/loglevels.h loglevels.tmp include/all.h.pch i3-command-parser.stamp i3-config-parser.stamp i3 test.config_parser test.commands_parser src/*.gcno src/cfgparse.* src/cmdparse.*
