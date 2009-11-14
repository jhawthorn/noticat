
noticat: noticat.vala
	valac --pkg dbus-glib-1 noticat.vala

clean:
	$(RM) noticat
