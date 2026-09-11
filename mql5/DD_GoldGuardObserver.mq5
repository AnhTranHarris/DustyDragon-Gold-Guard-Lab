#property strict
#property version   "0.110"
#property description "Passive telemetry observer for Gold Hunter V8. Research-only; never sends trade requests."

input string InpSymbolContains = "XAUUSD";
input long   InpHunterMagic    = 5555;
input int    InpTimerSeconds   = 1;
input int    InpNewsLookaheadMinutes = 120;
input string InpOutputFile     = "DustyDragon\\GoldGuard\\observer.csv";

int g_file = INVALID_HANDLE;
int g_cached_news_minutes = 2147483647;
string g_cached_event_name = "";
ulong g_pending_deals[];

bool IsHunterDeal(const ulong deal_ticket)
  {
   if(deal_ticket==0 || !HistoryDealSelect(deal_ticket))
      return(false);
   long magic=HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
   string symbol=HistoryDealGetString(deal_ticket,DEAL_SYMBOL);
   return(magic==InpHunterMagic && StringFind(symbol,InpSymbolContains)>=0);
  }

void EnqueueDeal(const ulong deal_ticket)
  {
   int n=ArraySize(g_pending_deals);
   if(ArrayResize(g_pending_deals,n+1,n+16)!=n+1)
     {
      PrintFormat("GoldGuardObserver failed to queue deal %I64u, error=%d",deal_ticket,GetLastError());
      return;
     }
   g_pending_deals[n]=deal_ticket;
  }

double SpreadPoints(const string symbol)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return(-1.0);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point<=0.0)
      return(-1.0);
   return((tick.ask-tick.bid)/point);
  }

int CountHunterPositions()
  {
   int total=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      string psymbol=PositionGetString(POSITION_SYMBOL);
      long magic=PositionGetInteger(POSITION_MAGIC);
      if(StringFind(psymbol,InpSymbolContains)>=0 && magic==InpHunterMagic)
         total++;
     }
   return(total);
  }

int CountHunterOrders()
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0)
         continue;
      string osymbol=OrderGetString(ORDER_SYMBOL);
      long magic=OrderGetInteger(ORDER_MAGIC);
      if(StringFind(osymbol,InpSymbolContains)>=0 && magic==InpHunterMagic)
         total++;
     }
   return(total);
  }

void RefreshNewsCache(const datetime now_server)
  {
   g_cached_news_minutes=2147483647;
   g_cached_event_name="";
   datetime to=now_server+(InpNewsLookaheadMinutes*60);
   MqlCalendarValue values[];
   ResetLastError();
   int n=CalendarValueHistory(values,now_server,to,NULL,"USD");
   if(n<=0)
      return;

   for(int i=0;i<n;i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id,ev))
         continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH)
         continue;
      int mins=(int)((values[i].time-now_server)/60);
      if(mins>=0 && mins<g_cached_news_minutes)
        {
         g_cached_news_minutes=mins;
         g_cached_event_name=ev.name;
        }
     }
  }

void WriteSnapshot(const string tag,const ulong deal_ticket=0,const bool flush_now=false)
  {
   if(g_file==INVALID_HANDLE)
      return;
   datetime now_server=TimeCurrent();
   FileSeek(g_file,0,SEEK_END);
   FileWrite(g_file,
             TimeToString(now_server,TIME_DATE|TIME_SECONDS),tag,_Symbol,
             DoubleToString(SpreadPoints(_Symbol),1),
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
             DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),2),
             DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2),
             DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),2),
             CountHunterPositions(),CountHunterOrders(),
             g_cached_news_minutes,g_cached_event_name,deal_ticket);
   if(flush_now)
      FileFlush(g_file);
  }

void DrainPendingDeals()
  {
   int n=ArraySize(g_pending_deals);
   for(int i=0;i<n;i++)
      WriteSnapshot("hunter_deal",g_pending_deals[i],false);
   if(n>0)
      ArrayResize(g_pending_deals,0);
  }

int OnInit()
  {
   g_file=FileOpen(InpOutputFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)
     {
      PrintFormat("GoldGuardObserver FileOpen failed, error=%d",GetLastError());
      return(INIT_FAILED);
     }
   if(FileSize(g_file)==0)
      FileWrite(g_file,"server_time","tag","symbol","spread_points","balance","equity","margin","margin_free","margin_level","hunter_positions","hunter_orders","high_impact_usd_minutes","event_name","deal_ticket");
   if(!EventSetTimer(MathMax(1,InpTimerSeconds)))
     {
      PrintFormat("GoldGuardObserver EventSetTimer failed, error=%d",GetLastError());
      FileClose(g_file);
      g_file=INVALID_HANDLE;
      return(INIT_FAILED);
     }
   RefreshNewsCache(TimeCurrent());
   WriteSnapshot("init",0,true);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DrainPendingDeals();
   WriteSnapshot("deinit",0,true);
   if(g_file!=INVALID_HANDLE)
     {
      FileClose(g_file);
      g_file=INVALID_HANDLE;
     }
  }

void OnTimer()
  {
   RefreshNewsCache(TimeCurrent());
   DrainPendingDeals();
   WriteSnapshot("timer",0,true);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0)
      return;
   if(IsHunterDeal(trans.deal))
      EnqueueDeal(trans.deal);
  }
