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
		return "log login "+config->credentials;
	}
	if (has_prefix(line,"log OK")) return "stats select inbox";
	if (sscanf(line,"* %d RECEN%c",int newmail,int T) && T=='T' && newmail) write("%%%% NEW MAIL: %d messages\n",newmail);
	if (has_prefix(line,"stats OK")) call_out(noop,config->period||60,conn);
}

void create()
{
	if (!G->G->curr_conn) call_out(connect,0);
	sscanf(Stdio.read_file("config.txt")||"","%{%s=%s\n%}",array config_arr);
	config=(mapping)config_arr;
	services[(config->port||143)|HOGAN_ACTIVE|HOGAN_LINEBASED]=imap;
}
