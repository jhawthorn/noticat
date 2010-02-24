/* vim:set noexpandtab shiftwidth=3 tabstop=3:*/

using X;
using GLib.FileUtils;

public const int DEFAULT_TIMEOUT = 3000;

public class Notification: Object{
	public uint id;
	public int priority;

	protected string _text;
	protected TimeVal _expiry;

	public virtual string text{
		get{
			return _text;
		}
		set{
			_text = value;
			displayText();
		}
	}
	public long remaining {
		get {
			TimeVal now = TimeVal();
			now.get_current_time();
			return (_expiry.tv_sec - now.tv_sec) * 1000 + (_expiry.tv_usec - now.tv_usec) / 1000;
		}
		set {
			_expiry.get_current_time();
			_expiry.add(value * 1000); /* miliseconds to microseconds */
			settimeout();
		}
	}
	public Notification(){
		notifications.prepend(this);
	}
	public static Notification getid(uint id){
		foreach(Notification notification in notifications){
			if(id == notification.id){
				return notification;
			}
		}
		return new Notification();
	}
	private void settimeout(){
		Timeout.add((uint)remaining, timer);
	}
	public virtual bool timer(){
		if(remaining <= 0){
			notifications.remove(this);
			displayText();
		}
		return false; /* One shot */
	}
}

Display d;
Window root;
List<Notification> notifications = new List<Notification>();

void dwmDisplay(string text){
	d.change_property(root, XA_WM_NAME, d.intern_atom("STRING", true), 8, 0, (uchar[])text, (int)text.length);
	//d.store_name(root, text);
	d.flush();
}

void displayText(){
	string s = "";
	foreach(Notification notification in notifications){
		s += notification.text;
		s += " ";
	}

	dwmDisplay(s.strip());
}

[DBus (name = "org.freedesktop.Notifications")]
public class NotificationServer : Object{
	uint id = 1;
	public uint Notify(string app_name, uint notification_id, string app_icon, string summary, string body, string[] actions, HashTable<string,Value?> hints, int timeout){
		if(notification_id == 0)
			notification_id = id++;
		if(timeout <= 0)
			timeout = DEFAULT_TIMEOUT;

		Notification n = Notification.getid(id);
		n.id = id;
		n.text = (summary + " " + body).strip();
		n.remaining = timeout;

		return notification_id;
	}
	public string[] GetCapabilities(){
		return {"body"};
	}
	public void NotificationClosed(uint id_in, uint reason_in){
	}
	public void CloseNotification(uint id){
	}
}

class Clock: Notification {
	public Clock(){
		id = 0;
		remaining = 1000;
		priority = -1;
	}
	public override string text{
		set{}
		get{
			TimeVal tv = TimeVal();
			Time t = Time.local(tv.tv_sec);
			_text = t.format("%X");
			return _text;
		}
	}
	public override bool timer(){
		TimeVal tv = TimeVal();
		remaining = 1000 - tv.tv_usec / 1000;
		displayText();
		return false; /* One shot */
	}
}

class BatteryMonitor: Notification {
	private string batdir;
	private string str;
	private int full_charge;
	public BatteryMonitor(){
		batdir = "/sys/class/power_supply/BAT0";
		id = 1;
		priority = -1;
		string tmp;
		try{
			get_contents(@batdir + "/charge_full", out tmp);
		}catch(FileError e){
			full_charge = 1;
		}
		full_charge = tmp.to_int();
		updatetime();
	}
	public override string text{
		set{}
		get{
			return str;
		}
	}
	private void updatetime(){
		remaining = 60000; /* Once a minute */
		try{
			get_contents(@batdir + "/charge_now", out _text);
			int i = _text.to_int() * 100 / full_charge;
			str = i.to_string();
		}catch(FileError e){
			str = "???";
		}
	}
	public override bool timer(){
		updatetime();
		return false; /* One shot */
	}
}

void main(){
	d = new Display();
	root = d.default_root_window();

	var loop = new MainLoop (null, false);

	try {
		new Clock();

		new BatteryMonitor();

		var conn = DBus.Bus.get(DBus.BusType.SESSION);

		dynamic DBus.Object bus = conn.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");

		uint request_name_result = bus.request_name("org.freedesktop.Notifications", (uint) 0);

		if (request_name_result != DBus.RequestNameReply.PRIMARY_OWNER) {
			stderr.printf("WARNING: another notification daemon already started\n");
		}

		var server = new NotificationServer();
		conn.register_object("/org/freedesktop/Notifications", server);

		loop.run ();
	}catch (Error e){
		stderr.printf("Oops: %s\n", e.message);
	}
}
