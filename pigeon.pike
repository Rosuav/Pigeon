mapping(int:function) services=([]); //Filled in below
mapping(string:string) config=([]);

void connect() {G->connect((["_portref":indices(services)[0],"_ip":config->ip]));}
void noop(mapping(string:mixed) conn) {if (conn==G->G->curr_conn) G->send(conn,"stats noop");}

string imap(mapping(string:mixed) conn,string line)
{
	if (!line) if (conn->_closing)
	{
		if (conn==G->G->curr_conn) {G->G->curr_conn=0; call_out(connect,1);}
		return 0;
	}
	else
	{
		if (!G->G->curr_conn) G->G->curr_conn=conn;
		else conn->_close=1;
		conn->_sendsuffix="\r\n";
		return "log login "+config->credentials;
	}
	if (has_index(conn,"stringlitlen"))
	{
		if (conn->stringlitlen>=sizeof(line)+2) {conn->stringlit+=line+"\n"; conn->stringlitlen-=sizeof(line)+2; return 0;}
		int len=m_delete(conn,"stringlitlen");
		conn->stringlit+=line[..len-1]; line=line[len..];
		if (sscanf(conn->cmdpfx,"* %*d FETCH (UID %d BODY[] ",int msgid) && msgid && line==")") catch
		{
			object msg=MIME.Message(conn->stringlit);
			mapping hdr=msg->headers; //We'll use this a lot
			//Bail out if the message doesn't fit our criteria
			if (config->flagword && !has_value(hdr->subject,config->flagword)) return 0;
			write(">> New pigeon from %s\n%s\n-----\n",hdr->from,String.trim_all_whites(msg->data));
			object del,close;
			object win=GTK2.Window((["title":"Pigeon by email"]))->add(GTK2.Vbox(0,0)
				->add(GTK2.Label("Pigeon from "+(hdr->from||hdr["return-path"]||"(unknown)")))
				->add(GTK2.TextView(GTK2.TextBuffer()->set_text(String.trim_all_whites(msg->data)+"\n"))->set_editable(0))
				->add(GTK2.HbuttonBox()
					->add(del=GTK2.Button((["label":"_Delete message","use-underline":1]))->set_sensitive(0)) //TODO: will require UUIDs or careful handling around EXPUNGE
					->add(close=GTK2.Button((["label":"_Close","use-underline":1])))
				)
			)->show_all()->set_keep_above(1);
			close->signal_connect("clicked",lambda() {win->destroy();});
			if (config->alertcmd) Process.Process(config.alertcmd);
		}; //Ignore any errors on decode, just skip the message
		return 0;
	}
	if (line!="" && line[-1]=='}')
	{
		//String literal notation. I'm assuming that there's never an open brace earlier in the
		//command than the one that ends it. There's a lot about IMAP that I'm shortcutting
		//horribly here; it works with my server (Courier-IMAP), and if it doesn't work for the
		//server you use, please submit a patch.
		sscanf(line,"%s{%d}",conn->cmdpfx,conn->stringlitlen);
		conn->stringlit="";
		return 0;
	}
	if (has_prefix(line,"log OK")) return "stats select inbox";
	if (sscanf(line,"* %d RECEN%c",int newmail,int T) && T=='T' && newmail) return "srch uid search new";
	if (sscanf(line,"* SEARCH%{ %d%}",array(array(int)) msgids) && msgids && sizeof(msgids)) return sprintf("%{newmail uid fetch %d (body[])\n%}",msgids);
	if (has_prefix(line,"stats OK")) call_out(noop,(int)config->period||60,conn);
}

void create()
{
	if (!G->G->curr_conn) call_out(connect,0);
	if (!G->G->GTK2) G->G->GTK2=GTK2.setup_gtk();
	sscanf(Stdio.read_file("config.txt")||"","%{%s=%s\n%}",array config_arr);
	config=(mapping)config_arr;
	services[(config->port||143)|HOGAN_ACTIVE|HOGAN_LINEBASED]=imap;
}
