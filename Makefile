
noticat: noticat.vala
	valac --pkg dbus-glib-1 --pkg x11 noticat.vala

clean:
	$(RM) noticat
